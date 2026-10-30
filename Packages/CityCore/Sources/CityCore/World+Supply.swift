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
    mutating func spawnSupplyCarriers(consumers: [(Building, [Good: Int])], events: inout [WorldEvent]) {
        // Dispatching moves goods, not buildings: list the buffers once.
        let buffers = goodsBuffers().filter { $0.state == .operational }
        for (consumer, needs) in consumers {
            guard let consumerRoad = anyAdjacentRoad(anchor: consumer.anchor, footprint: consumer.footprint) else { continue }
            let vehicle = CarrierConfig.vehicle(in: age(of: consumer.owner))
            for good in Good.allCases {
                guard let amount = needs[good] else { continue }
                while supplyCarrierCount(to: consumer.id) < CarrierConfig.perProducerCap {
                    let short = shortfall(of: good, at: consumer.id, amount: amount)
                    guard short > 0,
                          let (bufferID, path) = nearestBuffer(holding: good, toRoad: consumerRoad, among: buffers)
                    else { break }
                    let held = stockpiles[bufferID]?.quantity(of: good) ?? 0
                    let haul = CarrierConfig.haul(ready: min(held, short), along: path, vehicle: vehicle)
                    dispatchSupply(
                        good, from: bufferID, to: consumer.id, along: path,
                        haul: haul, events: &events
                    )
                }
            }
        }
    }

    /// Hubs short of a good their houses need pull it from the nearest other
    /// store of their owner on their road, one carrier per good at a time;
    /// with no store holding it, from the nearest other hub holding more than
    /// its own reserve. Short means below the hub's reserve: its reserve
    /// consumptions of what its served houses eat. A restock walks a basket
    /// (the hub's porter load) or takes the owner's cart on a long road.
    /// Spec: `warehouses-and-logistics` / Market hubs gather house goods.
    mutating func spawnRestockCarriers(service: HubService, events: inout [WorldEvent]) {
        var reserves: [EntityID: [Good: Int]] = [:]
        for hub in service.hubs {
            let factor = hub.kind.hub?.reserveConsumptions ?? 0
            for (good, eaten) in consumption(of: service.housesOf[hub.id] ?? []) {
                reserves[hub.id, default: [:]][good] = factor * eaten
            }
        }
        func surplus(of good: Good, at building: Building) -> Int {
            (stockpiles[building.id]?.quantity(of: good) ?? 0) - (reserves[building.id]?[good] ?? 0)
        }
        for hub in service.hubs {
            guard let spec = hub.kind.hub, let hubRoad = anyAdjacentRoad(anchor: hub.anchor, footprint: hub.footprint)
            else { continue }
            let buffers = goodsBuffers(of: hub.owner).filter { $0.state == .operational && $0.id != hub.id }
            let vehicle = CarrierConfig.vehicle(in: age(of: hub.owner))
            for (good, reserve) in (reserves[hub.id] ?? [:]).sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
                let short = shortfall(of: good, at: hub.id, below: reserve)
                let otherHubs = buffers.filter { $0.kind.hub != nil && surplus(of: good, at: $0) > 0 }
                let stores = buffers.filter { $0.kind.hub == nil }
                // Stores, then other hubs' surplus, and a granary's reserve last.
                guard short > 0, inboundUnits(to: hub.id, good: good).ofGood == 0,
                      let (source, path) = nearestBuffer(holding: good, toRoad: hubRoad, among: stores.filter { !Self.isDrawnLast($0) })
                      ?? nearestBuffer(holding: good, toRoad: hubRoad, among: otherHubs)
                      ?? nearestBuffer(holding: good, toRoad: hubRoad, among: stores.filter(Self.isDrawnLast))
                else { continue }
                let spare = buildings[source]?.kind.hub == nil
                    ? stockpiles[source]?.quantity(of: good) ?? 0
                    : buildings[source].map { surplus(of: good, at: $0) } ?? 0
                var haul = CarrierConfig.haul(ready: min(spare, short), along: path, vehicle: vehicle)
                if haul.vehicle == nil {
                    haul.amount = min(spare, short, spec.basketUnits)
                }
                dispatchSupply(good, from: source, to: hub.id, along: path, haul: haul, events: &events)
            }
        }
    }

    /// What `houses` eat of each good per interval, in `Good` order, counting
    /// the needs their next tier adds too: a house advances only while its
    /// hub holds those, so the hub keeps them before anyone eats them.
    private func consumption(of houses: [EntityID]) -> [(Good, Int)] {
        var eaten: [Good: Int] = [:]
        for house in houses {
            guard let pop = populations[house] else { continue }
            let needs = pop.tier.needs(in: culture) + (pop.tier.next?.needs(in: culture) ?? [])
            for good in Set(needs) {
                eaten[good, default: 0] += pop.nextConsumption(of: good)
            }
        }
        return Good.allCases.compactMap { good in eaten[good].map { (good, $0) } }
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

    /// Whether `consumer` should get more `good`: below twice the amount it
    /// uses at a time, counting units on their way, with room for one more.
    func needsSupply(_ consumer: EntityID, good: Good, amount: Int) -> Bool {
        supplyCarrierCount(to: consumer) < CarrierConfig.perProducerCap
            && shortfall(of: good, at: consumer, amount: amount) > 0
    }

    /// Units of `good` `consumer` could take now: what keeps it below twice
    /// `amount`, counting units on their way, and no more than its room
    /// beyond what is already on its way to it.
    func shortfall(of good: Good, at consumer: EntityID, amount: Int) -> Int {
        shortfall(of: good, at: consumer, below: amount * 2)
    }

    /// Units of `good` that would bring `building` up to `target`, counting
    /// units on their way, and no more than its room beyond those.
    func shortfall(of good: Good, at building: EntityID, below target: Int) -> Int {
        let pile = stockpiles[building]
        let inbound = inboundUnits(to: building, good: good)
        let short = target - (pile?.quantity(of: good) ?? 0) - inbound.ofGood
        return min(short, (pile?.room(for: good) ?? 0) - inbound.all)
    }

    mutating func dispatchSupply(
        _ good: Good,
        from buffer: EntityID,
        to consumer: EntityID,
        along path: [TileCoordinate],
        haul: (amount: Int, vehicle: Vehicle?) = (1, nil),
        events: inout [WorldEvent]
    ) {
        stockpiles[buffer]?.withdraw(good, amount: haul.amount)
        let carrierID = EntityID(raw: nextEntityRaw)
        nextEntityRaw &+= 1
        carriers[carrierID] = Carrier(
            id: carrierID,
            path: path,
            mission: .retrieve(good: good, amount: haul.amount, fromWarehouse: buffer, toConsumer: consumer),
            vehicle: haul.vehicle
        )
        events.append(.carrierDeparted(carrier: carrierID, from: path[0], good: good))
    }

    /// Units on their way to `consumer`, from storage or straight from a
    /// producer: of `good`, and of every good. A handcart brings several.
    func inboundUnits(to consumer: EntityID, good: Good) -> (ofGood: Int, all: Int) {
        carriers.values.reduce(into: (ofGood: 0, all: 0)) { sum, carrier in
            switch carrier.mission {
            case let .retrieve(carried, amount, _, toConsumer), let .deliverToConsumer(carried, amount, _, toConsumer):
                guard toConsumer == consumer else { return }
                sum.all += amount
                if carried == good { sum.ofGood += amount }
            case .deliver, .deliverToConstructionSite:
                return
            }
        }
    }

    /// Carriers on the way to `consumer`, from storage or straight from a
    /// producer.
    func supplyCarrierCount(to consumer: EntityID) -> Int {
        carriers.values.count { carrier in
            switch carrier.mission {
            case let .retrieve(_, _, _, toConsumer), let .deliverToConsumer(_, _, _, toConsumer):
                toConsumer == consumer
            case .deliver, .deliverToConstructionSite:
                false
            }
        }
    }

    /// A granary keeps a reserve: every draw takes from the other stores
    /// first, in its own order, and from a granary only when those hold
    /// none of the good. Spec: `goods-and-production` / Granaries are drawn
    /// from last.
    static func isDrawnLast(_ store: Building) -> Bool {
        store.kind == .granary
    }

    /// The first sort key of a draw order: 0 for ordinary stores, 1 for
    /// those drawn last.
    static func drawRank(_ store: Building) -> Int {
        isDrawnLast(store) ? 1 : 0
    }

    /// `stores` in the order a draw takes from them: their own order, with
    /// the granaries moved to the end.
    static func granariesLast(_ stores: [Building]) -> [Building] {
        stores.filter { !isDrawnLast($0) } + stores.filter(isDrawnLast)
    }

    /// Operational goods buffer holding `good` with the shortest road
    /// path to `road`; ties go to the lower entity ID. A granary only when
    /// no other buffer qualifies (`isDrawnLast`).
    /// `buffers` are the operational buffers in entity order, when the
    /// caller has listed them already.
    func nearestBuffer(
        holding good: Good, toRoad road: TileCoordinate, among buffers: [Building]? = nil
    ) -> (EntityID, [TileCoordinate])? {
        let candidates = buffers ?? goodsBuffers().filter { $0.state == .operational }
        return nearestBuffer(holding: good, toRoad: road, in: candidates.filter { !Self.isDrawnLast($0) })
            ?? nearestBuffer(holding: good, toRoad: road, in: candidates.filter(Self.isDrawnLast))
    }

    private func nearestBuffer(
        holding good: Good, toRoad road: TileCoordinate, in buffers: [Building]
    ) -> (EntityID, [TileCoordinate])? {
        var best: (EntityID, [TileCoordinate])?
        for buffer in buffers {
            guard (stockpiles[buffer.id]?.quantity(of: good) ?? 0) > 0,
                  let bufferRoad = anyAdjacentRoad(
                      anchor: buffer.anchor,
                      footprint: buffer.footprint
                  ),
                  let path = roadPath(from: bufferRoad, to: road)
            else { continue }
            if best.map({ path.count < $0.1.count }) ?? true {
                best = (buffer.id, path)
            }
        }
        return best
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
