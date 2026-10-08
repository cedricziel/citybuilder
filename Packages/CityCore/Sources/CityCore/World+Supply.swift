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
            .filter { $0.state == .operational && !(ProductionCatalog.recipe(for: $0.kind)?.inputs.isEmpty ?? true) }
            .sorted { $0.id.raw < $1.id.raw }
        for consumer in consumers {
            guard let recipe = ProductionCatalog.recipe(for: consumer.kind),
                  let consumerRoad = anyAdjacentRoad(
                      anchor: consumer.anchor,
                      footprint: BuildingCatalog.spec(for: consumer.kind).footprint
                  )
            else { continue }
            for good in Good.allCases {
                guard let amount = recipe.inputs[good] else { continue }
                while needsSupply(consumer.id, good: good, amount: amount) {
                    guard let (bufferID, path) = nearestBuffer(holding: good, toRoad: consumerRoad) else { break }
                    dispatchSupply(good, from: bufferID, to: consumer.id, along: path, events: &events)
                }
            }
        }
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
                  let path = PathFinder.path(from: bufferRoad, to: road, in: roadGraph)
            else { continue }
            if best.map({ path.count < $0.1.count }) ?? true {
                best = (buffer.id, path)
            }
        }
        return best
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
        return PathFinder.path(from: from, to: to, in: roadGraph) != nil
    }
}
