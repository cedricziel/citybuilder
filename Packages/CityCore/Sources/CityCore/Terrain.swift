import Foundation

/// Terrain classification of a single tile. Per spec `world-terrain`.
public enum TerrainType: String, CaseIterable, Codable, Sendable {
    case grass
    case forest
    case beach
    case water
    case mountain
}

/// Integer tile coordinate. Per spec `world-terrain` ("Coordinates are integer").
public struct TileCoordinate: Hashable, Codable, Sendable {
    public let x: Int
    public let y: Int

    public init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }
}

/// Why a placement attempt was rejected. The `code` property doubles
/// as a stable error string for logging.
public enum PlacementRejection: Hashable, Sendable {
    case outOfBounds
    case terrainNotBuildable
    case tileOccupied
    /// Shore-placement building's footprint covered no land tiles
    /// (spec `buildings-and-construction` / Shore-placement rule).
    case shoreRequiresLandTile
    /// Shore-placement building's footprint covered no water tiles.
    case shoreRequiresWaterTile
    /// Island's goods-buffer stockpiles cannot supply the building's
    /// `materialCost`. Carries the per-good shortfall (need − have)
    /// for every good that came up short. Spec: `buildings-and-construction`
    /// / Placement rejected when island materials are short.
    case insufficientMaterials([Good: Int])
    /// Too few footprint tiles of the building's required terrain.
    case needsTerrain(TerrainType)
    /// The building's tech is not researched yet. Spec: `research`.
    case locked(Tech)
    /// A later tech replaced this building. Spec: `historical-ages` /
    /// Obsolete buildings.
    case obsolete(Tech)
    /// A land tile lies on an island owned by someone else, named here.
    /// Spec: `buildings-and-construction` / Placement on another owner's
    /// island is rejected.
    case foreignIsland(Owner)

    /// Stable string code suitable for logging and analytics.
    public var code: String {
        switch self {
        case .outOfBounds: "out_of_bounds"
        case .terrainNotBuildable: "terrain_not_buildable"
        case .tileOccupied: "tile_occupied"
        case .shoreRequiresLandTile: "shore_requires_land_tile"
        case .shoreRequiresWaterTile: "shore_requires_water_tile"
        case .insufficientMaterials: "insufficient_materials"
        case .needsTerrain: "needs_terrain"
        case .locked: "locked"
        case .obsolete: "obsolete"
        case .foreignIsland: "foreign_island"
        }
    }
}

public enum PlacementResult: Hashable, Sendable {
    case allowed
    case rejected(PlacementRejection)
}
