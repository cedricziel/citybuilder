import Foundation

/// Input supply and lumberjack catchment. Kept out of `Systems.swift`
/// so that file stays under SwiftLint's length ceiling. Spec:
/// `goods-and-production` / Producers draw inputs from goods buffers,
/// Producer behavior.
extension World {
    /// First forest tile within the catchment, scanning row-major from
    /// the top-left corner, or nil when the catchment is cleared.
    func firstForestInCatchment(of kind: BuildingKind, anchor: TileCoordinate) -> TileCoordinate? {
        firstInCatchment(of: kind, anchor: anchor, where: isUnoccupiedForest)
    }

    /// First catchment tile matching `isTarget`, row-major from the
    /// top-left corner.
    func firstInCatchment(
        of kind: BuildingKind, anchor: TileCoordinate, where isTarget: (TileCoordinate) -> Bool
    ) -> TileCoordinate? {
        var first: TileCoordinate?
        visitCatchment(of: kind, anchor: anchor, where: isTarget) { tile in
            first = tile
            return false
        }
        return first
    }

    /// Unoccupied forest tiles within the catchment of a `kind` at `anchor`.
    func forestTiles(inCatchmentOf kind: BuildingKind, at anchor: TileCoordinate) -> Int {
        var count = 0
        visitCatchment(of: kind, anchor: anchor, where: isUnoccupiedForest) { _ in
            count += 1
            return true
        }
        return count
    }

    func isUnoccupiedForest(_ tile: TileCoordinate) -> Bool {
        terrain(at: tile) == .forest && occupiedTiles[tile] == nil
    }

    /// The footprint of every kind with a catchment, looked up once: a
    /// building spec carries its material costs, which `visitCatchment`
    /// would otherwise copy on every call.
    private static let catchmentFootprints = Dictionary(uniqueKeysWithValues: BuildingKind.allCases.compactMap { kind in
        kind.catchmentRadius.map { _ in (kind, BuildingCatalog.spec(for: kind).footprint) }
    })

    /// Visits the tiles matching `isTarget` within `kind`'s catchment
    /// radius of its footprint at `anchor`, row-major from the top-left
    /// corner, while `visit` returns true. A kind without a catchment
    /// visits nothing. Lumberjacks and foresters share it and it runs per
    /// building per tick, so it allocates nothing.
    func visitCatchment(
        of kind: BuildingKind, anchor: TileCoordinate,
        where isTarget: (TileCoordinate) -> Bool, _ visit: (TileCoordinate) -> Bool
    ) {
        guard let radius = kind.catchmentRadius, let footprint = Self.catchmentFootprints[kind] else { return }
        for y in anchor.y - radius ... anchor.y + footprint.height - 1 + radius {
            for x in anchor.x - radius ... anchor.x + footprint.width - 1 + radius {
                let tile = TileCoordinate(x: x, y: y)
                if isTarget(tile), !visit(tile) { return }
            }
        }
    }

    /// Dispatch buffer→producer carriers for producers short of inputs.
    /// Producers and goods are visited in a fixed order so replays stay
    /// identical.
    /// `consumers` come from `operationalConsumers()`.
    mutating func spawnSupplyCarriers(
        consumers: [(Building, [Good: Int])],
        rest: RestContexts,
        events: inout [WorldEvent]
    ) {
        // Dispatching moves goods, not buildings: list the buffers once.
        let buffers = goodsBuffers().filter { $0.state == .operational }
        for (consumer, needs) in consumers {
            guard let consumerRoad = anyAdjacentRoad(
                anchor: consumer.anchor,
                footprint: BuildingCatalog.spec(for: consumer.kind).footprint
            ),
                let island = islandFor(building: consumer, tileToIsland: rest.tileToIsland)
            else { continue }
            for good in Good.allCases {
                guard let amount = needs[good] else { continue }
                while needsSupply(
                    consumer.id,
                    good: good,
                    amount: amount,
                    context: rest.context(of: consumer.owner, on: island, in: self)
                ) {
                    guard let (bufferID, path) = nearestBuffer(holding: good, toRoad: consumerRoad, among: buffers) else { break }
                    dispatchSupply(good, from: bufferID, to: consumer.id, along: path, events: &events)
                    rest.draw(good, of: consumer.owner, on: island)
                }
            }
        }
    }

    /// Operational buildings with goods to be supplied, in entity order,
    /// with those goods and amounts.
    func operationalConsumers() -> [(Building, [Good: Int])] {
        buildings.values
            .filter { $0.state == .operational }
            .map { ($0, Self.suppliedGoods(of: $0)) }
            .filter { !$0.1.isEmpty }
            .sorted { $0.0.id.raw < $1.0.id.raw }
    }

    /// Goods supply carriers bring to `building`, with the amount used at
    /// a time: its recipe inputs plus its fuel (design D5).
    static func suppliedGoods(of building: Building) -> [Good: Int] {
        var needs = activeRecipe(of: building)?.inputs ?? [:]
        if let fuel = building.kind.fuel {
            needs[fuel.good, default: 0] += fuel.amount
        }
        return needs
    }

    /// Whether `consumer` should get more `good`. Every route that feeds
    /// a producer asks this, so a resting producer gets nothing from any
    /// of them. `context` describes the consumer's island, built once per
    /// pass by the caller.
    func needsSupply(_ consumer: EntityID, good: Good, amount: Int, context: IslandRestContext) -> Bool {
        let inbound = supplyCarrierCount(to: consumer)
        // Every unit on the way needs room on arrival, or it is lost.
        guard inbound < CarrierConfig.perProducerCap,
              (stockpiles[consumer]?.freeSpace ?? 0) > inbound,
              let building = buildings[consumer]
        else { return false }
        let onHand = stockpiles[consumer]?.quantity(of: good) ?? 0
        return onHand + supplyCarrierCount(to: consumer, good: good) < amount * 2
            && isResting(building, context: context) == nil
    }

    mutating func dispatchSupply(
        _ good: Good,
        from buffer: EntityID,
        to consumer: EntityID,
        along path: [TileCoordinate],
        events: inout [WorldEvent]
    ) {
        stockpiles[buffer]?.withdraw(good, amount: 1)
        let carrierID = EntityID(raw: nextEntityRaw)
        nextEntityRaw &+= 1
        carriers[carrierID] = Carrier(
            id: carrierID,
            path: path,
            mission: .retrieve(good: good, amount: 1, fromWarehouse: buffer, toConsumer: consumer)
        )
        events.append(.carrierDeparted(carrier: carrierID, from: path[0], good: good))
    }

    /// Carriers on the way to `consumer`, from storage or straight from a
    /// producer, optionally only those carrying `good`.
    func supplyCarrierCount(to consumer: EntityID, good: Good? = nil) -> Int {
        carriers.values.count { carrier in
            switch carrier.mission {
            case let .retrieve(carried, _, _, toConsumer), let .deliverToConsumer(carried, _, _, toConsumer):
                toConsumer == consumer && (good == nil || carried == good)
            case .deliver, .deliverToConstructionSite:
                false
            }
        }
    }

    /// Operational goods buffer holding `good` with the shortest road
    /// path to `road`; ties go to the lower entity ID.
    /// `buffers` are the operational buffers in entity order, when the
    /// caller has listed them already.
    func nearestBuffer(
        holding good: Good, toRoad road: TileCoordinate, among buffers: [Building]? = nil
    ) -> (EntityID, [TileCoordinate])? {
        var best: (EntityID, [TileCoordinate])?
        for buffer in buffers ?? goodsBuffers().filter({ $0.state == .operational }) {
            guard (stockpiles[buffer.id]?.quantity(of: good) ?? 0) > 0,
                  let bufferRoad = anyAdjacentRoad(
                      anchor: buffer.anchor,
                      footprint: BuildingCatalog.spec(for: buffer.kind).footprint
                  ),
                  let path = roadPath(from: bufferRoad, to: road)
            else { continue }
            if best.map({ path.count < $0.1.count }) ?? true {
                best = (buffer.id, path)
            }
        }
        return best
    }

    /// Withdraw up to `amount` of `good` from operational goods buffers
    /// on `building`'s road network, lowest entity ID first. Returns the
    /// amount actually withdrawn.
    mutating func consume(_ good: Good, amount: Int, by building: Building) -> Int {
        let footprint = BuildingCatalog.spec(for: building.kind).footprint
        var remaining = amount
        for buffer in goodsBuffers() where remaining > 0 && buffer.state == .operational {
            let bufferFootprint = BuildingCatalog.spec(for: buffer.kind).footprint
            guard (stockpiles[buffer.id]?.quantity(of: good) ?? 0) > 0,
                  sharesRoadNetwork(building.anchor, footprint, with: buffer.anchor, bufferFootprint)
            else { continue }
            remaining -= stockpiles[buffer.id]?.withdraw(good, amount: remaining) ?? 0
        }
        return amount - remaining
    }

    /// Takes up to `amount` of `good` from `buffers`, in the given order.
    /// Returns the units taken.
    @discardableResult
    mutating func drain(_ good: Good, upTo amount: Int, from buffers: [Building]) -> Int {
        var left = amount
        for buffer in buffers where left > 0 {
            left -= stockpiles[buffer.id]?.withdraw(good, amount: left) ?? 0
        }
        return amount - left
    }

    /// Puts up to `amount` of `good` into `buffers`, in the given order,
    /// as far as they have room. Returns the units placed.
    @discardableResult
    mutating func fill(_ good: Good, upTo amount: Int, into buffers: [Building]) -> Int {
        var placed = 0
        for buffer in buffers where placed < amount {
            placed += stockpiles[buffer.id]?.deposit(good, amount: amount - placed) ?? 0
        }
        return placed
    }

    /// Road path between two road tiles. Roads never cross water, so
    /// tiles on different islands are answered without a search.
    func roadPath(from start: TileCoordinate, to goal: TileCoordinate) -> [TileCoordinate]? {
        let islands = tileToIslandMap()
        guard islands[start] == islands[goal] else { return nil }
        return PathFinder.path(from: start, to: goal, in: roadGraph)
    }

    /// True when a road path joins a road next to `anchor`'s footprint
    /// and a road next to `other`'s footprint.
    func sharesRoadNetwork(
        _ anchor: TileCoordinate,
        _ footprint: Footprint,
        with other: TileCoordinate,
        _ otherFootprint: Footprint
    ) -> Bool {
        guard let from = anyAdjacentRoad(anchor: anchor, footprint: footprint),
              let to = anyAdjacentRoad(anchor: other, footprint: otherFootprint)
        else { return false }
        return roadPath(from: from, to: to) != nil
    }
}
