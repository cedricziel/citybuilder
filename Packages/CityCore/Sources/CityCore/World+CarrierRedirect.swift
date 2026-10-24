import Foundation

/// Carriers whose destination could not take their goods: full, or
/// demolished while they walked. Spec: `warehouses-and-logistics` /
/// Carried goods go on to storage.
extension World {
    /// `carrier` sent on with the `units` its destination did not take:
    /// to the nearest goods buffer of its owner with room, else back to
    /// where the goods came from when that has room. Nil when no
    /// building has room for them, and the goods are lost as before:
    /// a town whose stores are full drops its overflow rather than
    /// stalling every producer behind it.
    func redirected(_ carrier: Carrier, carrying units: Int) -> Carrier? {
        let mission = carrier.mission
        guard let here = carrier.currentTile ?? carrier.path.last,
              let owner = buildings[mission.source]?.owner ?? buildings[mission.destination]?.owner,
              let (target, path) = nearestRoom(from: here, owner: owner, avoiding: mission.destination, source: mission.source)
        else { return nil }
        var onward = carrier
        onward.pathIndex = 0
        onward.path = path
        onward.mission = mission.redirected(to: target, amount: units)
        return onward
    }

    /// The nearest operational goods buffer of `owner` with free room,
    /// other than `avoiding`, by road from `tile`; ties go to the lower
    /// entity ID. Falls back to `source` when it still stands and has
    /// room.
    private func nearestRoom(
        from tile: TileCoordinate, owner: Owner, avoiding: EntityID, source: EntityID
    ) -> (EntityID, [TileCoordinate])? {
        func pathTo(_ building: Building) -> [TileCoordinate]? {
            guard building.id != avoiding, (stockpiles[building.id]?.freeSpace ?? 0) > 0,
                  let road = anyAdjacentRoad(anchor: building.anchor, footprint: BuildingCatalog.spec(for: building.kind).footprint)
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
        if best == nil, let origin = buildings[source], let path = pathTo(origin) {
            best = (origin.id, path)
        }
        return best
    }
}
