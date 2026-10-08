import Foundation

/// Input supply and lumberjack catchment. Kept out of `Systems.swift`
/// so that file stays under SwiftLint's length ceiling. Spec:
/// `goods-and-production` / Producers draw inputs from goods buffers,
/// Producer behavior.
extension World {
    /// Chebyshev radius around a lumberjack's footprint it harvests from.
    static let lumberjackCatchmentRadius = 2

    /// First forest tile within the catchment, scanning row-major from
    /// the top-left corner, or nil when the catchment is cleared.
    func firstForestInCatchment(anchor: TileCoordinate, footprint: Footprint) -> TileCoordinate? {
        let radius = Self.lumberjackCatchmentRadius
        for y in anchor.y - radius ... anchor.y + footprint.height - 1 + radius {
            for x in anchor.x - radius ... anchor.x + footprint.width - 1 + radius {
                let tile = TileCoordinate(x: x, y: y)
                if terrain(at: tile) == .forest, occupiedTiles[tile] == nil {
                    return tile
                }
            }
        }
        return nil
    }

    /// Dispatch buffer→producer carriers for producers short of inputs.
    /// Producers and goods are visited in a fixed order so replays stay
    /// identical.
    mutating func spawnSupplyCarriers(events: inout [WorldEvent]) {
        let consumers = buildings.values
            .filter { $0.state == .operational }
            .map { ($0, Self.suppliedGoods(of: $0)) }
            .filter { !$0.1.isEmpty }
            .sorted { $0.0.id.raw < $1.0.id.raw }
        for (consumer, needs) in consumers {
            guard let consumerRoad = anyAdjacentRoad(
                anchor: consumer.anchor,
                footprint: BuildingCatalog.spec(for: consumer.kind).footprint
            )
            else { continue }
            for good in Good.allCases {
                guard let amount = needs[good] else { continue }
                while needsSupply(consumer.id, good: good, amount: amount) {
                    guard let (bufferID, path) = nearestBuffer(holding: good, toRoad: consumerRoad) else { break }
                    dispatchSupply(good, from: bufferID, to: consumer.id, along: path, events: &events)
                }
            }
        }
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

    private func needsSupply(_ consumer: EntityID, good: Good, amount: Int) -> Bool {
        guard supplyCarrierCount(to: consumer) < CarrierConfig.perProducerCap else { return false }
        let onHand = stockpiles[consumer]?.quantity(of: good) ?? 0
        return onHand + supplyCarrierCount(to: consumer, good: good) < amount * 2
    }

    private mutating func dispatchSupply(
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

    private func supplyCarrierCount(to consumer: EntityID, good: Good? = nil) -> Int {
        carriers.values.count { carrier in
            guard case let .retrieve(carried, _, _, toConsumer) = carrier.mission else { return false }
            return toConsumer == consumer && (good == nil || carried == good)
        }
    }

    /// Operational goods buffer holding `good` with the shortest road
    /// path to `road`; ties go to the lower entity ID.
    private func nearestBuffer(holding good: Good, toRoad road: TileCoordinate) -> (EntityID, [TileCoordinate])? {
        var best: (EntityID, [TileCoordinate])?
        for buffer in goodsBuffers() where buffer.state == .operational {
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
