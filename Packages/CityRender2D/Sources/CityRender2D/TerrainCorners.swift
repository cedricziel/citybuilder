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

    /// Grass changes with the season, so a grass edge has autumn and winter sets
    /// (`terrain-grass-beach-t3-winter`); other pairs look the same all year.
    public func assetName(in season: Season) -> String {
        guard upper == .grass else { return assetName }
        switch season {
        case .spring, .summer: return assetName
        case .autumn: return assetName + "-autumn"
        case .winter: return assetName + "-winter"
        }
    }
}

/// Visual-only terrain blending (rendering-2_5d: Terrain transitions from corner terrain, design D6).
/// Simulation and placement keep each tile's own `TerrainType`.
///
/// Vertex (c, r) is the top corner of tile (c, r), shared with tiles (c-1, r-1), (c, r-1) and (c-1, r).
/// Tile (c, r) has corners N = (c, r), E = (c+1, r), S = (c+1, r+1), W = (c, r+1).
public enum TerrainCorners {
    /// The four tiles sharing a vertex, as offsets from it.
    static let tilesAroundVertex = [(-1, -1), (0, -1), (-1, 0), (0, 0)]
    /// A tile's corners N, E, S, W, as vertex offsets from the tile.
    static let cornerOffsets = [(0, 0), (1, 0), (1, 1), (0, 1)]

    /// The terrain at a vertex. Forest and mountain count as grass; a vertex touching both grass
    /// and water is beach, so beach always separates the two.
    public static func vertex(_ vertex: TileCoordinate, terrain: (TileCoordinate) -> TerrainType?) -> TerrainType? {
        let around = tilesAroundVertex.compactMap { dx, dy in
            terrain(TileCoordinate(x: vertex.x + dx, y: vertex.y + dy)).map(blendClass)
        }
        guard !around.isEmpty else { return nil }
        if around.contains(.grass), around.contains(.water) { return .beach }
        if around.contains(.water) { return .water }
        if around.contains(.beach) { return .beach }
        return .grass
    }

    /// The transition tile for `coord`, or nil when its corners agree. Every kind blends: forest and
    /// mountain stand on grass, with their trees and rocks on top (terrain-v2, design D3).
    public static func transition(at coord: TileCoordinate, terrain: (TileCoordinate) -> TerrainType?) -> TerrainTransition? {
        guard terrain(coord) != nil else { return nil }
        let corners = cornerOffsets.compactMap { dx, dy in
            vertex(TileCoordinate(x: coord.x + dx, y: coord.y + dy), terrain: terrain)
        }
        return transition(corners: corners)
    }

    /// The transition for corner terrains N, E, S, W, or nil when they agree.
    static func transition(corners: [TerrainType]) -> TerrainTransition? {
        guard corners.count == 4, Set(corners).count == 2 else { return nil }
        let pair: (upper: TerrainType, lower: TerrainType) = corners.contains(.grass) ? (.grass, .beach) : (.beach, .water)
        let mask = corners.enumerated().reduce(0) { mask, corner in corner.element == pair.upper ? mask | (1 << corner.offset) : mask }
        return TerrainTransition(upper: pair.upper, lower: pair.lower, mask: mask)
    }

    static func blendClass(_ kind: TerrainType) -> TerrainType {
        TerrainObject.kinds.contains(kind) ? .grass : kind
    }
}

/// Every tile's transition for one terrain grid, computed once: each vertex is resolved a single time
/// instead of four lookups per tile per frame. Terrain is static, so the scene keeps one map and
/// rebuilds it only when the grid changes.
public struct TerrainTransitionMap: Sendable {
    public let width: Int
    public let height: Int
    let grid: [TerrainType]
    private let transitions: [TerrainTransition?]

    public init(width: Int, height: Int, grid: [TerrainType]) {
        self.width = width
        self.height = height
        self.grid = grid
        let terrain: (TileCoordinate) -> TerrainType? = { coord in
            guard coord.x >= 0, coord.x < width, coord.y >= 0, coord.y < height else { return nil }
            return grid[coord.y * width + coord.x]
        }
        var vertices = [TerrainType?](repeating: nil, count: (width + 1) * (height + 1))
        for vy in 0 ... height {
            for vx in 0 ... width {
                vertices[vy * (width + 1) + vx] = TerrainCorners.vertex(TileCoordinate(x: vx, y: vy), terrain: terrain)
            }
        }
        var transitions = [TerrainTransition?](repeating: nil, count: width * height)
        for y in 0 ..< height {
            for x in 0 ..< width {
                let corners = TerrainCorners.cornerOffsets.compactMap { dx, dy in vertices[(y + dy) * (width + 1) + x + dx] }
                transitions[y * width + x] = TerrainCorners.transition(corners: corners)
            }
        }
        self.transitions = transitions
    }

    public func transition(at coord: TileCoordinate) -> TerrainTransition? {
        guard coord.x >= 0, coord.x < width, coord.y >= 0, coord.y < height else { return nil }
        return transitions[coord.y * width + coord.x]
    }

    /// Whether this map was built from the same grid. Array `==` returns at once when both arrays
    /// share storage, which they do while the world's terrain is unchanged.
    public func matches(width: Int, height: Int, grid: [TerrainType]) -> Bool {
        self.width == width && self.height == height && self.grid == grid
    }
}
