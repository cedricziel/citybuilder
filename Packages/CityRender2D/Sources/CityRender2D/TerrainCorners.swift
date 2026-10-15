import CityCore

/// A corner-mask transition tile: `terrain-<upper>-<lower>-t<mask>`, with mask bits
/// N=1, E=2, S=4, W=8 marking the corners that carry `upper`.
public struct TerrainTransition: Hashable, Sendable {
    public let upper: TerrainType
    public let lower: TerrainType
    public let mask: Int

    public init(upper: TerrainType, lower: TerrainType, mask: Int) {
        self.upper = upper
        self.lower = lower
        self.mask = mask
    }

    public var assetName: String {
        "terrain-\(upper.rawValue)-\(lower.rawValue)-t\(mask)"
    }
}

/// Visual-only terrain blending (rendering-2_5d: Terrain transitions from corner terrain, design D6).
/// Simulation and placement keep each tile's own `TerrainType`.
///
/// Vertex (c, r) is the top corner of tile (c, r), shared with tiles (c-1, r-1), (c, r-1) and (c-1, r).
/// Tile (c, r) has corners N = (c, r), E = (c+1, r), S = (c+1, r+1), W = (c, r+1).
public enum TerrainCorners {
    /// The terrain at a vertex. Forest and mountain count as grass; a vertex touching both grass
    /// and water is beach, so beach always separates the two.
    public static func vertex(_ vertex: TileCoordinate, terrain: (TileCoordinate) -> TerrainType?) -> TerrainType? {
        let around = [(-1, -1), (0, -1), (-1, 0), (0, 0)].compactMap { dx, dy in
            terrain(TileCoordinate(x: vertex.x + dx, y: vertex.y + dy)).map(blendClass)
        }
        guard !around.isEmpty else { return nil }
        if around.contains(.grass), around.contains(.water) { return .beach }
        if around.contains(.water) { return .water }
        if around.contains(.beach) { return .beach }
        return .grass
    }

    /// The transition tile for `coord`, or nil when its corners agree or its kind doesn't blend
    /// (forest and mountain keep their own sprites).
    public static func transition(at coord: TileCoordinate, terrain: (TileCoordinate) -> TerrainType?) -> TerrainTransition? {
        guard let own = terrain(coord), [.grass, .beach, .water].contains(own) else { return nil }
        let corners = [(0, 0), (1, 0), (1, 1), (0, 1)].compactMap { dx, dy in
            vertex(TileCoordinate(x: coord.x + dx, y: coord.y + dy), terrain: terrain)
        }
        guard corners.count == 4, Set(corners).count == 2 else { return nil }
        let pair: (upper: TerrainType, lower: TerrainType) = corners.contains(.grass) ? (.grass, .beach) : (.beach, .water)
        let mask = corners.enumerated().reduce(0) { mask, corner in corner.element == pair.upper ? mask | (1 << corner.offset) : mask }
        return TerrainTransition(upper: pair.upper, lower: pair.lower, mask: mask)
    }

    private static func blendClass(_ kind: TerrainType) -> TerrainType {
        switch kind {
        case .forest, .mountain: .grass
        default: kind
        }
    }
}
