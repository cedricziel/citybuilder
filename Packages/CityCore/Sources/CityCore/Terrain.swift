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

/// Why a placement attempt was rejected. Strings double as stable error codes.
public enum PlacementRejection: String, Codable, Sendable {
    case outOfBounds = "out_of_bounds"
    case terrainNotBuildable = "terrain_not_buildable"
    case tileOccupied = "tile_occupied"
    /// Shore-placement building's footprint covered no land tiles
    /// (spec `buildings-and-construction` / Shore-placement rule).
    case shoreRequiresLandTile = "shore_requires_land_tile"
    /// Shore-placement building's footprint covered no water tiles.
    case shoreRequiresWaterTile = "shore_requires_water_tile"
}

public enum PlacementResult: Equatable, Sendable {
    case allowed
    case rejected(PlacementRejection)
}
