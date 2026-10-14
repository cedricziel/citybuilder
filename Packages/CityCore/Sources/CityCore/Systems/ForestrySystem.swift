import Foundation

/// Foresters and the trees and open ground in reach. Spec: `forestry`.
extension World {
    /// A building that plants forest: its kind has a planting cycle.
    static func isPlanter(_ kind: BuildingKind) -> Bool {
        kind.plantTicks != nil
    }

    /// Each operational forester, in entity order, advances its cycle
    /// while its catchment holds open grass, at half pace in winter, and
    /// plants the first open grass tile when the cycle completes
    /// (design D2, D3). Runs after production, so a tree planted on tick N
    /// can be cut on tick N + 1 at the earliest.
    mutating func runForestrySystem(events: inout [WorldEvent]) {
        let foresters = buildings.values
            .compactMap { building in building.state == .operational ? building.kind.plantTicks.map { (building, $0) } : nil }
            .sorted { $0.0.id.raw < $1.0.id.raw }
        guard !foresters.isEmpty else { return }
        let tileToIsland = tileToIslandMap()
        for (forester, cycle) in foresters {
            let footprint = BuildingCatalog.spec(for: forester.kind).footprint
            let isOpen = openGrass(for: forester.owner, tileToIsland: tileToIsland)
            guard let tile = firstInCatchment(anchor: forester.anchor, footprint: footprint, where: isOpen) else { continue }
            var progress = productions[forester.id] ?? ProductionProgress()
            if !(isCropWinter && Self.seasonalCrops.contains(forester.kind) && tickCount.isMultiple(of: 2)) {
                progress.ticksThisCycle &+= 1
            }
            if progress.ticksThisCycle >= cycle {
                terrainGrid[tile.y * mapWidth + tile.x] = .forest
                events.append(.forestPlanted(at: tile, forester: forester.id))
                progress.ticksThisCycle = 0
            }
            productions[forester.id] = progress
        }
    }

    /// Unoccupied forest a lumberjack hut would reach, or open grass a
    /// forester would reach, from `anchor`, built or not. Tiles under
    /// the footprint itself never count. Read-only (design D5).
    func catchmentCount(kind: BuildingKind, anchor: TileCoordinate, owner: Owner) -> Int {
        catchmentCount(kind: kind, anchor: anchor, owner: owner, tileToIsland: tileToIslandMap())
    }

    /// Trees or open grass in reach of every player hut and forester.
    func catchmentCounts(tileToIsland: [TileCoordinate: IslandID]) -> [EntityID: Int] {
        let reporting = buildings.values.filter { building in
            building.owner == .player && (building.kind == .lumberjackHut || Self.isPlanter(building.kind))
        }
        return Dictionary(uniqueKeysWithValues: reporting.map { building in
            let count = catchmentCount(kind: building.kind, anchor: building.anchor, owner: building.owner, tileToIsland: tileToIsland)
            return (building.id, count)
        })
    }

    /// Whether a tile is grass that no building occupies, on an island
    /// `owner` owns.
    func openGrass(for owner: Owner, tileToIsland: [TileCoordinate: IslandID]) -> (TileCoordinate) -> Bool {
        { tile in
            guard self.terrain(at: tile) == .grass, self.occupiedTiles[tile] == nil, let island = tileToIsland[tile]
            else { return false }
            return self.owner(ofIsland: island) == owner
        }
    }

    private func catchmentCount(
        kind: BuildingKind, anchor: TileCoordinate, owner: Owner, tileToIsland: [TileCoordinate: IslandID]
    ) -> Int {
        let isTarget: (TileCoordinate) -> Bool
        if kind == .lumberjackHut {
            isTarget = isUnoccupiedForest
        } else if Self.isPlanter(kind) {
            isTarget = openGrass(for: owner, tileToIsland: tileToIsland)
        } else {
            return 0
        }
        let footprint = BuildingCatalog.spec(for: kind).footprint
        let columns = anchor.x ..< anchor.x + footprint.width, rows = anchor.y ..< anchor.y + footprint.height
        var count = 0
        visitCatchment(anchor: anchor, footprint: footprint, where: isTarget) { tile in
            if !(columns.contains(tile.x) && rows.contains(tile.y)) { count += 1 }
            return true
        }
        return count
    }
}
