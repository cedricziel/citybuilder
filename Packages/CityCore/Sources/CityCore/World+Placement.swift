import Foundation

/// The placement rules behind `canPlace`, split so callers that check
/// many candidates in one go (the rival AI) look the island map up once.
extension World {
    /// Every placement rule except materials: island owner, culture,
    /// research, uniqueness, bounds, occupancy, terrain and shore.
    func siteRejection(
        _ kind: BuildingKind,
        at anchor: TileCoordinate,
        for owner: Owner,
        tileToIsland: [TileCoordinate: IslandID]
    ) -> PlacementRejection? {
        let spec = BuildingCatalog.spec(for: kind)
        let tiles = spec.footprint.tiles(anchor: anchor)
        let rejection = foreignIslandRejection(tiles: tiles, for: owner, tileToIsland: tileToIsland)
            ?? researchOrTerrainRejection(kind, tiles: tiles, for: owner)
            ?? uniquenessRejection(kind, for: owner)
        if let rejection {
            return rejection
        }
        var landCount = 0
        var waterCount = 0
        for tile in tiles {
            guard contains(tile) else { return .outOfBounds }
            if occupiedTiles[tile] != nil { return .tileOccupied }
            if terrain(at: tile) == .water {
                guard spec.shorePlacement != nil else { return .terrainNotBuildable }
                waterCount += 1
            } else {
                landCount += 1
            }
        }
        if let shore = spec.shorePlacement {
            if landCount < shore.minLandTiles { return .shoreRequiresLandTile }
            if waterCount < shore.minWaterTiles { return .shoreRequiresWaterTile }
        }
        return nil
    }

    /// Rejects a building whose island can neither supply nor produce
    /// its materials.
    func materialRejection(
        _ kind: BuildingKind,
        at anchor: TileCoordinate,
        for owner: Owner,
        tileToIsland: [TileCoordinate: IslandID]
    ) -> PlacementRejection? {
        let cost = materialCost(of: kind, for: owner)
        guard !cost.isEmpty else { return nil }
        let shortfall = materialShortfall(cost: cost, anchor: anchor, tileToIsland: tileToIsland)
        return shortfall.isEmpty ? nil : .insufficientMaterials(shortfall)
    }

    /// The materials `kind` costs `owner`. A rival's lumberjack hut costs
    /// none, so a rival whose huts have cut all their forest can always
    /// start cutting again (design D5).
    func materialCost(of kind: BuildingKind, for owner: Owner) -> [Good: Int] {
        owner != .player && kind == .lumberjackHut ? [:] : BuildingCatalog.spec(for: kind).materialCost
    }
}
