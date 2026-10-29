import Foundation

/// Carriers whose destination could not take their goods: full, or
/// demolished while they walked. Spec: `warehouses-and-logistics` /
/// Producers ship only where there is room, and Carried goods go on to
/// storage.
extension World {
    /// `carrier` with the `units` its destination did not take, sent on.
    ///
    /// - A supply carrier waits at its consumer while that stands, and
    ///   delivers once it has room. One already sent on to a store goes
    ///   on again when that store fills.
    /// - Otherwise the goods go on to the nearest store of their owner
    ///   with room for them, counting what is already on its way there,
    ///   else back to where they came from when that stands and has room.
    /// - With nowhere to go they wait at their destination while it
    ///   stands, looking again each tick, so nothing is lost to a full
    ///   store. A construction site never keeps a carrier waiting.
    ///
    /// Nil when the destination is gone and nothing has room: the goods are
    /// lost, as before.
    func rerouted(_ carrier: Carrier, carrying units: Int) -> Carrier? {
        let mission = carrier.mission.carrying(units)
        var waiting = carrier
        waiting.mission = mission
        let destinationStands: Bool = switch mission {
        case .deliverToConstructionSite: false
        case .deliver, .retrieve, .deliverToConsumer: stockpiles[mission.destination] != nil
        }
        let atConsumer = buildings[mission.destination].map { !Self.logisticsBufferKinds.contains($0.kind) } ?? false
        if case .retrieve = mission, destinationStands, atConsumer { return waiting }
        let here = carrier.currentTile ?? carrier.path.last ?? TileCoordinate(x: 0, y: 0)
        // With both ends demolished, the island underfoot names the owner.
        let owner = buildings[mission.source]?.owner ?? buildings[mission.destination]?.owner
            ?? islandID(at: here).map(owner(ofIsland:))
        if let owner, let (target, path) = nearestRoom(for: mission, from: here, owner: owner) {
            var onward = carrier
            onward.pathIndex = 0
            onward.path = path
            onward.mission = mission.redirected(to: target, amount: units)
            return onward
        }
        return destinationStands ? waiting : nil
    }

    /// The nearest operational goods buffer of `owner` with room for the
    /// mission's good beyond what is already on its way there, other than
    /// its destination, by road from `tile`; ties go to the lower entity
    /// ID. Falls back to the mission's source when it still stands and has
    /// room.
    private func nearestRoom(
        for mission: Carrier.Mission, from tile: TileCoordinate, owner: Owner
    ) -> (EntityID, [TileCoordinate])? {
        let inbound = InboundGoods(carriers.values)
        func pathTo(_ building: Building) -> [TileCoordinate]? {
            guard building.id != mission.destination, let pile = stockpiles[building.id],
                  pile.room(for: mission.good) > inbound.pending(of: mission.good, to: building.id, in: pile),
                  let road = anyAdjacentRoad(anchor: building.anchor, footprint: building.footprint)
            else { return nil }
            return roadPath(from: tile, to: road)
        }
        var best: (EntityID, [TileCoordinate])?
        for buffer in goodsBuffers(of: owner) where buffer.state == .operational {
            guard let path = pathTo(buffer) else { continue }
            if best.map({ path.count < $0.1.count }) ?? true {
                best = (buffer.id, path)
            }
        }
        if best == nil, let origin = buildings[mission.source], let path = pathTo(origin) {
            best = (origin.id, path)
        }
        return best
    }
}

/// Units of each good on their way to each building, so a store's room
/// for a good is not promised twice.
final class InboundGoods {
    private var units: [EntityID: [Good: Int]] = [:]

    init(_ carriers: some Sequence<Carrier>) {
        for carrier in carriers {
            add(carrier.mission)
        }
    }

    func add(_ mission: Carrier.Mission) {
        units[mission.destination, default: [:]][mission.good, default: 0] += mission.amount
    }

    func count(of good: Good, to building: EntityID) -> Int {
        units[building]?[good] ?? 0
    }

    /// Units on their way to `building` that take room from `good` in
    /// `pile`: those of `good` for a per-good store, all of them for a
    /// shared stockpile.
    func pending(of good: Good, to building: EntityID, in pile: Stockpile) -> Int {
        pile.limitsEachGood ? count(of: good, to: building) : units[building]?.values.reduce(0, +) ?? 0
    }
}
