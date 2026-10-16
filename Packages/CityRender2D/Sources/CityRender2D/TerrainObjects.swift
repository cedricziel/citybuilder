import CityCore

/// What stands on a tile (terrain-v2, design D3): a clump of trees on forest, an outcrop on
/// mountain, and now and then a single tree in a meadow near the forest. Visual only: simulation and
/// placement keep each tile's own terrain.
public struct TerrainObject: Hashable, Sendable {
    public enum Density: String, Sendable, CaseIterable {
        case single, sparse, medium, dense, peak
    }

    public let kind: TerrainType
    public let density: Density
    public let variant: Int

    public static let variants = 4

    /// `terrain-<kind>-<density>[-<season>][-v<n>]`. Trees have autumn and winter looks; rock only a
    /// winter one. Spring and summer use the plain name.
    public func assetName(in season: Season) -> String {
        var stem = "terrain-\(kind.rawValue)-\(density.rawValue)"
        switch season {
        case .autumn where kind == .forest: stem += "-autumn"
        case .winter: stem += "-winter"
        default: break
        }
        return SpriteAtlas.variantAssetName(stem: stem, variant: variant)
    }

    /// The plain look: what a missing seasonal sprite falls back to.
    public var assetName: String {
        assetName(in: .spring)
    }
}

/// Every tile's object for one terrain grid and its occupancy, worked out once: the edge distance of
/// each forest and mountain region comes from one breadth-first search per kind, so a frame only
/// looks objects up.
public struct TerrainObjectMap: Sendable {
    public let width: Int
    public let height: Int
    let grid: [TerrainType]
    let occupancy: [TileCoordinate: EntityID]
    private let objects: [TerrainObject?]

    public init(width: Int, height: Int, grid: [TerrainType], occupancy: [TileCoordinate: EntityID]) {
        self.width = width
        self.height = height
        self.grid = grid
        self.occupancy = occupancy
        let forest = Self.edgeDistance(of: .forest, width: width, height: height, grid: grid)
        let mountain = Self.edgeDistance(of: .mountain, width: width, height: height, grid: grid)
        var objects = [TerrainObject?](repeating: nil, count: width * height)
        for y in 0 ..< height {
            for x in 0 ..< width {
                let coord = TileCoordinate(x: x, y: y)
                guard occupancy[coord] == nil else { continue }
                let index = y * width + x
                let crowded = Self.neighbours(of: coord).contains { occupancy[$0] != nil }
                let variant = SpriteAtlas.variantIndex(coord: coord, count: TerrainObject.variants)
                let density: TerrainObject.Density? = switch grid[index] {
                case .forest: Self.forestDensity(distance: forest[index], coord: coord, crowded: crowded)
                case .mountain: Self.rockDensity(distance: mountain[index], coord: coord, crowded: crowded)
                case .grass: Self.meadowTree(at: coord, forest: forest, width: width, height: height, crowded: crowded)
                default: nil
                }
                if let density {
                    objects[index] = TerrainObject(kind: grid[index] == .mountain ? .mountain : .forest, density: density, variant: variant)
                }
            }
        }
        self.objects = objects
    }

    public func object(at coord: TileCoordinate) -> TerrainObject? {
        guard coord.x >= 0, coord.x < width, coord.y >= 0, coord.y < height else { return nil }
        return objects[coord.y * width + coord.x]
    }

    /// Whether this map was built from the same grid and occupancy. Both compare in constant time
    /// while they share storage with the world's, which they do while nothing changes.
    public func matches(width: Int, height: Int, grid: [TerrainType], occupancy: [TileCoordinate: EntityID]) -> Bool {
        self.width == width && self.height == height && self.grid == grid && self.occupancy == occupancy
    }

    // MARK: - Density (design D3)

    private static let ladder: [TerrainObject.Density] = [.sparse, .medium, .dense]

    /// Edge tiles are sparse (one in three medium, so the edge is no hedge), the next ring medium,
    /// the interior dense; a tile next to a building drops one step.
    static func forestDensity(distance: Int, coord: TileCoordinate, crowded: Bool) -> TerrainObject.Density {
        var step = min(distance, 3) - 1
        if distance == 1, hash(coord, salt: 7) % 3 == 0 {
            step = 1
        }
        return ladder[max(0, step - (crowded ? 1 : 0))]
    }

    /// Rock thins toward its edge the same way; deep inside, world noise raises some tiles to peaks.
    static func rockDensity(distance: Int, coord: TileCoordinate, crowded: Bool) -> TerrainObject.Density {
        let step = max(0, min(distance, 3) - 1 - (crowded ? 1 : 0))
        if step == 2, distance >= 4, !crowded, hash(TileCoordinate(x: coord.x / 3, y: coord.y / 3), salt: 11) % 3 != 0 {
            return .peak
        }
        return ladder[step]
    }

    /// One meadow tile in about sixteen within two tiles of forest grows a single tree, never next to
    /// a building or road.
    static func meadowTree(at coord: TileCoordinate, forest: [Int], width: Int, height: Int, crowded: Bool) -> TerrainObject.Density? {
        guard !crowded, hash(coord, salt: 13) % 16 == 0 else { return nil }
        for dy in -2 ... 2 {
            for dx in -2 ... 2 {
                let x = coord.x + dx, y = coord.y + dy
                if x >= 0, x < width, y >= 0, y < height, forest[y * width + x] > 0 {
                    return .single
                }
            }
        }
        return nil
    }

    private static func hash(_ coord: TileCoordinate, salt: UInt32) -> UInt32 {
        SpriteAtlas.tileHash(Int32(truncatingIfNeeded: coord.x), Int32(truncatingIfNeeded: coord.y), salt: salt)
    }

    private static func neighbours(of coord: TileCoordinate) -> [TileCoordinate] {
        (-1 ... 1).flatMap { dy in (-1 ... 1).compactMap { dx in
            dx == 0 && dy == 0 ? nil : TileCoordinate(x: coord.x + dx, y: coord.y + dy)
        } }
    }

    /// Edge-neighbour steps from each tile of `kind` to the nearest tile that is not (1 on the edge),
    /// 0 for every other tile. The map's border counts as an edge.
    static func edgeDistance(of kind: TerrainType, width: Int, height: Int, grid: [TerrainType]) -> [Int] {
        var distance = [Int](repeating: 0, count: grid.count)
        var frontier: [Int] = []
        for index in grid.indices where grid[index] == kind {
            let x = index % width, y = index / width
            let onEdge = x == 0 || y == 0 || x == width - 1 || y == height - 1
                || grid[index - 1] != kind || grid[index + 1] != kind || grid[index - width] != kind || grid[index + width] != kind
            distance[index] = onEdge ? 1 : Int.max
            if onEdge {
                frontier.append(index)
            }
        }
        var step = 1
        while !frontier.isEmpty {
            step += 1
            var next: [Int] = []
            for index in frontier {
                for neighbour in [index - 1, index + 1, index - width, index + width] where distance[neighbour] == Int.max {
                    distance[neighbour] = step
                    next.append(neighbour)
                }
            }
            frontier = next
        }
        return distance
    }
}
