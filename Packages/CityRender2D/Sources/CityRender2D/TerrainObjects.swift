import CityCore

/// What stands on a tile (terrain-v2, design D3): a clump of trees on forest, an outcrop on
/// mountain. Visual only: simulation and placement keep each tile's own terrain. Meadow trees wait
/// for a design lumberjacks and foresters can see.
public struct TerrainObject: Hashable, Sendable {
    public enum Density: String, Sendable, CaseIterable {
        case sparse, medium, dense, peak
    }

    public let kind: TerrainType
    public let density: Density
    public let variant: Int

    public static let variants = 4
    /// The terrain kinds drawn as objects over grass ground, with no ground sprite of their own.
    public static let kinds: Set<TerrainType> = [.forest, .mountain]

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
/// looks objects up, and a building placed or cleared only redoes the tiles round it.
public struct TerrainObjectMap: Sendable {
    public let width: Int
    public let height: Int
    let grid: [TerrainType]
    private(set) var occupancy: [TileCoordinate: EntityID]
    private let forest: [Int]
    private let mountain: [Int]
    private var occupied: [Bool]
    private var objects: [TerrainObject?]

    public init(width: Int, height: Int, grid: [TerrainType], occupancy: [TileCoordinate: EntityID]) {
        self.width = width
        self.height = height
        self.grid = grid
        self.occupancy = occupancy
        forest = Self.edgeDistance(of: .forest, width: width, height: height, grid: grid)
        mountain = Self.edgeDistance(of: .mountain, width: width, height: height, grid: grid)
        occupied = [Bool](repeating: false, count: grid.count)
        objects = [TerrainObject?](repeating: nil, count: grid.count)
        for tile in occupancy.keys {
            if let index = index(of: tile) {
                occupied[index] = true
            }
        }
        for index in grid.indices {
            objects[index] = object(forIndex: index)
        }
    }

    /// Moves this map to a new occupancy over the same grid: only the tiles whose occupancy changed
    /// and the ring round each are worked out again. Returns the tiles whose object changed.
    @discardableResult
    public mutating func update(occupancy newOccupancy: [TileCoordinate: EntityID]) -> [TileCoordinate] {
        guard newOccupancy != occupancy else { return [] }
        let changed = Set(occupancy.keys).symmetricDifference(newOccupancy.keys)
        occupancy = newOccupancy
        var redo = Set<Int>()
        for tile in changed {
            if let index = index(of: tile) {
                occupied[index] = newOccupancy[tile] != nil
            }
            for (dx, dy) in Self.ringAndSelf {
                if let index = index(of: TileCoordinate(x: tile.x + dx, y: tile.y + dy)) {
                    redo.insert(index)
                }
            }
        }
        var moved: [TileCoordinate] = []
        for index in redo {
            let object = object(forIndex: index)
            guard object != objects[index] else { continue }
            objects[index] = object
            moved.append(TileCoordinate(x: index % width, y: index / width))
        }
        return moved
    }

    /// The eight tiles round a tile, as offsets.
    private static let ring = [(-1, -1), (0, -1), (1, -1), (-1, 0), (1, 0), (-1, 1), (0, 1), (1, 1)]
    private static let ringAndSelf = ring + [(0, 0)]

    private func index(of tile: TileCoordinate) -> Int? {
        tile.x >= 0 && tile.x < width && tile.y >= 0 && tile.y < height ? tile.y * width + tile.x : nil
    }

    private func object(forIndex index: Int) -> TerrainObject? {
        let kind = grid[index]
        guard kind == .forest || kind == .mountain, !occupied[index] else { return nil }
        let x = index % width, y = index / width
        let coord = TileCoordinate(x: x, y: y)
        let crowded = Self.ring.contains { dx, dy in
            let nx = x + dx, ny = y + dy
            return nx >= 0 && nx < width && ny >= 0 && ny < height && occupied[ny * width + nx]
        }
        let density = kind == .forest
            ? Self.forestDensity(distance: forest[index], coord: coord, crowded: crowded)
            : Self.rockDensity(distance: mountain[index], coord: coord, crowded: crowded)
        return TerrainObject(kind: kind, density: density, variant: SpriteAtlas.variantIndex(coord: coord, count: TerrainObject.variants))
    }

    public func object(at coord: TileCoordinate) -> TerrainObject? {
        index(of: coord).flatMap { objects[$0] }
    }

    /// Whether this map was built from the same grid. It compares in constant time while it shares
    /// storage with the world's, which it does while nothing changes.
    public func matches(width: Int, height: Int, grid: [TerrainType]) -> Bool {
        self.width == width && self.height == height && self.grid == grid
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

    /// Rock thins toward its edge the same way. Inside a region, smooth world noise lays out open
    /// stretches of boulders with scree and grass between, ordinary rock, and ridges of tall tors.
    static func rockDensity(distance: Int, coord: TileCoordinate, crowded: Bool) -> TerrainObject.Density {
        let step = max(0, min(distance, 3) - 1 - (crowded ? 1 : 0))
        guard step == 2 else { return ladder[step] }
        let relief = Noise.value(Float(coord.x) / 3.5, Float(coord.y) / 3.5, 11)
        if relief < -0.15 { return .medium }
        return relief > 0.35 && distance >= 4 ? .peak : .dense
    }

    private static func hash(_ coord: TileCoordinate, salt: UInt32) -> UInt32 {
        SpriteAtlas.tileHash(Int32(truncatingIfNeeded: coord.x), Int32(truncatingIfNeeded: coord.y), salt: salt)
    }

    /// Edge-neighbour steps from each tile of `kind` to the nearest tile that is not (1 on the edge),
    /// 0 for every other tile. The map's border counts as an edge.
    static func edgeDistance(of kind: TerrainType, width: Int, height: Int, grid: [TerrainType]) -> [Int] {
        var distance = [Int](repeating: 0, count: grid.count)
        var frontier: [Int] = []
        for index in grid.indices where grid[index] == kind {
            var inside = 0
            forEachEdgeNeighbour(of: index, width: width, height: height) { inside += grid[$0] == kind ? 1 : 0 }
            distance[index] = inside == 4 ? Int.max : 1
            if inside < 4 {
                frontier.append(index)
            }
        }
        var step = 1
        while !frontier.isEmpty {
            step += 1
            var next: [Int] = []
            for index in frontier {
                forEachEdgeNeighbour(of: index, width: width, height: height) { neighbour in
                    if distance[neighbour] == Int.max {
                        distance[neighbour] = step
                        next.append(neighbour)
                    }
                }
            }
            frontier = next
        }
        return distance
    }

    /// Calls `body` with each of the up to four edge neighbours of `index` inside the map.
    private static func forEachEdgeNeighbour(of index: Int, width: Int, height: Int, _ body: (Int) -> Void) {
        let x = index % width, y = index / width
        if x > 0 { body(index - 1) }
        if x < width - 1 { body(index + 1) }
        if y > 0 { body(index - width) }
        if y < height - 1 { body(index + width) }
    }
}
