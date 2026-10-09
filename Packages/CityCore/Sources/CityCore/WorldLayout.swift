import Foundation

/// Named world topology selectable at new-game creation. Spec:
/// `world-terrain` / Requirement: World layout.
public enum WorldLayout: String, Codable, Sendable, CaseIterable {
    case singleIsland = "single-island"
    case archipelago
}

/// Stable identifier for an island in the world. Derived from the
/// scan order of connected-component detection, which is itself
/// deterministic given a fixed terrain grid.
public typealias IslandID = UInt16

/// Climate band attached to each island. Default rule (M6): north
/// half of the map is `.temperate`, south half is `.tropical`. The
/// follow-up `add-island-specialization` change uses these values
/// to gate building catalogs; M6 only persists the field.
public enum Climate: String, Codable, Sendable, CaseIterable {
    case temperate
    case tropical
}

/// Axis-aligned bounding box in tile coordinates.
public struct TileBoundingBox: Hashable, Codable, Sendable {
    public let minX: Int
    public let minY: Int
    public let maxX: Int
    public let maxY: Int

    public init(minX: Int, minY: Int, maxX: Int, maxY: Int) {
        self.minX = minX
        self.minY = minY
        self.maxX = maxX
        self.maxY = maxY
    }
}

/// Per-island metadata cached on the `World`. The list is
/// recomputed only when terrain changes (initial gen, forest
/// harvest, future terraforming).
public struct Island: Hashable, Codable, Sendable {
    public let id: IslandID
    public let tileCount: Int
    public let bounds: TileBoundingBox
    public let climate: Climate
    /// Deterministic generated name. Picked at world-gen from
    /// `IslandNameTable.entries` via a hash of (seed, island center,
    /// IslandID). Persists across save/load via Codable.
    public let name: String

    public init(
        id: IslandID,
        tileCount: Int,
        bounds: TileBoundingBox,
        climate: Climate,
        name: String
    ) {
        self.id = id
        self.tileCount = tileCount
        self.bounds = bounds
        self.climate = climate
        self.name = name
    }
}

public extension Island {
    /// Default Codable decoder that defaults the new `name` field to
    /// a deterministic pick when missing, so pre-name v2 saves continue
    /// to load with the same name they'd be generated with today.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(IslandID.self, forKey: .id)
        self.tileCount = try container.decode(Int.self, forKey: .tileCount)
        self.bounds = try container.decode(TileBoundingBox.self, forKey: .bounds)
        self.climate = try container.decode(Climate.self, forKey: .climate)
        if let decoded = try container.decodeIfPresent(String.self, forKey: .name) {
            self.name = decoded
        } else {
            // Pre-name v2 save: regenerate from a default-seeded picker.
            // The seed-bearing path is unavailable here (Codable has no
            // world context), so fall back to a seed of 0 — matches the
            // value used by `World.newGame()`'s default path.
            self.name = IslandNameTable.pick(seed: 0, bounds: self.bounds, id: self.id)
        }
    }
}

/// 64-entry hand-curated medieval/coastal name table. Index picked
/// deterministically via `IslandNameTable.pick`. Entries are stable
/// across releases — saved worlds keep their original name even if
/// the table is later extended.
public enum IslandNameTable {
    public static let entries: [String] = [
        "Greenwood", "Stoneholm", "Tinmouth", "Fairhaven", "Old Salt",
        "North Reach", "Bay of Knives", "Whaleback", "Linden", "Marrow",
        "Ashford", "Briarwick", "Coldcliff", "Dunsea", "Elderfen",
        "Foxbridge", "Glasswater", "Hawkroost", "Ironkeep", "Juniper",
        "Kelpwall", "Larkfield", "Mosshold", "Nettlebay", "Otterford",
        "Pinecrest", "Quailbrook", "Ravenshore", "Sablecliff", "Thornfast",
        "Umberwick", "Vellholm", "Wexford", "Yarrowmoor", "Zephyrhold",
        "Bramblerock", "Cinderport", "Driftwell", "Embershore", "Frostmere",
        "Gullhaven", "Hollowfen", "Inglewood", "Jasperreach", "Kirkstead",
        "Lowtide", "Mariner's Rest", "Northwatch", "Oaktide", "Petrelroost",
        "Quartzbay", "Redthorn", "Saltford", "Tidemoor", "Underholm",
        "Vesperdeep", "Windward", "Yewmark", "Cragsfoot", "Dewspar",
        "Eastreach", "Mossbar", "Stillwick", "Lanternfast"
    ]

    /// Picks a name index deterministically from a seed, the island's
    /// bounding-box center, and the island ID. Same inputs → same name.
    /// A name already in `taken` steps to the next free entry, so the
    /// islands of one world never share a name.
    public static func pick(
        seed: UInt64, bounds: TileBoundingBox, id: IslandID, taken: Set<String> = []
    ) -> String {
        let centerX = (bounds.minX + bounds.maxX) / 2
        let centerY = (bounds.minY + bounds.maxY) / 2
        let hashValue = hash(seed: seed, centerX: centerX, centerY: centerY, id: id)
        let start = Int(hashValue % UInt64(entries.count))
        let free = (0 ..< entries.count).lazy
            .map { entries[(start + $0) % entries.count] }
            .first { !taken.contains($0) }
        return free ?? entries[start]
    }

    /// SplitMix-style mixer over the inputs. Integer-only, byte-stable
    /// across platforms and Swift versions.
    private static func hash(
        seed: UInt64, centerX: Int, centerY: Int, id: IslandID
    ) -> UInt64 {
        var hashValue = seed &+ 0x9E37_79B9_7F4A_7C15
        hashValue &+= UInt64(bitPattern: Int64(centerX)) &* 0xBF58_476D_1CE4_E5B9
        hashValue &+= UInt64(bitPattern: Int64(centerY)) &* 0x94D0_49BB_1331_11EB
        hashValue &+= UInt64(id) &* 0xD1B5_4A32_D192_ED03
        hashValue ^= hashValue >> 30
        hashValue &*= 0xBF58_476D_1CE4_E5B9
        hashValue ^= hashValue >> 27
        return hashValue
    }
}

/// Deterministic, integer-only generator for the `.archipelago`
/// layout. Avoids the existing IslandGenerator's `Double` wobble
/// math so the cross-platform determinism gate stays byte-identical
/// once this fixture is exercised on Linux.
public enum ArchipelagoGenerator {
    public static let width = 300
    public static let height = 300

    /// Five hand-placed islands of varying sizes. Each is a tile
    /// rectangle with rounded corners (integer Chebyshev disc). The
    /// shapes are stable across seeds — the seed only perturbs the
    /// per-tile forest/beach decoration via the world's RNG, not the
    /// island silhouettes themselves.
    private struct IslandSpec {
        let centerX: Int
        let centerY: Int
        let radiusX: Int
        let radiusY: Int
    }

    private static let islandSpecs: [IslandSpec] = [
        IslandSpec(centerX: 60, centerY: 60, radiusX: 38, radiusY: 30),
        IslandSpec(centerX: 220, centerY: 50, radiusX: 32, radiusY: 28),
        IslandSpec(centerX: 150, centerY: 150, radiusX: 50, radiusY: 40),
        IslandSpec(centerX: 70, centerY: 230, radiusX: 28, radiusY: 28),
        IslandSpec(centerX: 230, centerY: 240, radiusX: 36, radiusY: 32)
    ]

    public static func generate(seed: UInt64) -> [TerrainType] {
        var grid: [TerrainType] = Array(repeating: .water, count: width * height)
        for spec in islandSpecs {
            paintIsland(into: &grid, spec: spec)
        }
        decorate(grid: &grid, seed: seed)
        return grid
    }

    private static func paintIsland(into grid: inout [TerrainType], spec: IslandSpec) {
        let beachInset = 2
        for tileY in (spec.centerY - spec.radiusY) ... (spec.centerY + spec.radiusY) {
            guard tileY >= 0, tileY < height else { continue }
            for tileX in (spec.centerX - spec.radiusX) ... (spec.centerX + spec.radiusX) {
                guard tileX >= 0, tileX < width else { continue }
                // Integer ellipse test: (dx/rx)² + (dy/ry)² ≤ 1.
                let dxScaled = (tileX - spec.centerX) * spec.radiusY
                let dyScaled = (tileY - spec.centerY) * spec.radiusX
                let lhs = dxScaled * dxScaled + dyScaled * dyScaled
                let rhs = spec.radiusX * spec.radiusX * spec.radiusY * spec.radiusY
                guard lhs <= rhs else { continue }
                // Inner — grass; rim — beach (a few rings in from the edge).
                let dxInset = (tileX - spec.centerX) * (spec.radiusY - beachInset)
                let dyInset = (tileY - spec.centerY) * (spec.radiusX - beachInset)
                let inner = (spec.radiusX - beachInset) * (spec.radiusY - beachInset)
                let innerLhs = dxInset * dxInset + dyInset * dyInset
                let innerRhs = inner * inner
                grid[tileY * width + tileX] = innerLhs <= innerRhs ? .grass : .beach
            }
        }
    }

    private static func decorate(grid: inout [TerrainType], seed: UInt64) {
        // Deterministic per-tile decoration via the integer hash of
        // (tileX, tileY, seed). Forest dots scattered over grass;
        // mountain dots scattered over inland grass.
        for tileY in 0 ..< height {
            for tileX in 0 ..< width {
                let idx = tileY * width + tileX
                guard grid[idx] == .grass else { continue }
                let hash = tileHash(tileX: tileX, tileY: tileY, seed: seed)
                let bucket = hash & 0x3F
                if bucket < 10 {
                    grid[idx] = .forest
                } else if bucket == 0x3F {
                    grid[idx] = .mountain
                }
            }
        }
    }

    private static func tileHash(tileX: Int, tileY: Int, seed: UInt64) -> UInt64 {
        var hash = seed &+ 0x9E37_79B9_7F4A_7C15
        hash &+= UInt64(bitPattern: Int64(tileX)) &* 0xBF58_476D_1CE4_E5B9
        hash &+= UInt64(bitPattern: Int64(tileY)) &* 0x94D0_49BB_1331_11EB
        hash ^= hash >> 30
        hash &*= 0xBF58_476D_1CE4_E5B9
        hash ^= hash >> 27
        return hash
    }
}

/// Connected-component detection over non-water buildable tiles.
/// Used to derive the `Island` list from the terrain grid. Buildable
/// = grass, forest, beach, mountain (everything except water).
enum IslandDetector {
    static func buildableTile(_ kind: TerrainType) -> Bool {
        kind != .water
    }

    static func detectIslands(
        width: Int,
        height: Int,
        terrain: [TerrainType],
        mapHeightForClimate: Int,
        seed: UInt64
    ) -> [Island] {
        detect(
            width: width,
            height: height,
            terrain: terrain,
            mapHeightForClimate: mapHeightForClimate,
            seed: seed
        ).islands
    }

    /// Run the connected-component scan once and return both the
    /// island list and the per-tile component map. The snapshot uses
    /// the map for `island(at:)`; world-gen uses the list.
    static func detect(
        width: Int,
        height: Int,
        terrain: [TerrainType],
        mapHeightForClimate: Int,
        seed: UInt64
    ) -> (islands: [Island], tileToIsland: [TileCoordinate: IslandID]) {
        guard width > 0, height > 0 else { return ([], [:]) }
        var component = [Int](repeating: -1, count: width * height)
        var islands: [Island] = []
        var nextID: IslandID = 1
        let grid = Grid(width: width, height: height, terrain: terrain)
        for startY in 0 ..< height {
            for startX in 0 ..< width {
                let startIdx = startY * width + startX
                guard component[startIdx] == -1, buildableTile(terrain[startIdx])
                else { continue }
                let id = nextID
                nextID &+= 1
                let stats = floodFill(
                    start: (startX, startY),
                    id: id,
                    grid: grid,
                    component: &component
                )
                islands.append(Self.makeIsland(
                    id: id,
                    stats: stats,
                    mapHeightForClimate: mapHeightForClimate,
                    seed: seed,
                    taken: Set(islands.map(\.name))
                ))
            }
        }
        return (islands, makeTileMap(width: width, height: height, component: component))
    }

    private struct Grid {
        let width: Int
        let height: Int
        let terrain: [TerrainType]
    }

    private struct ComponentStats {
        let tileCount: Int
        let minX: Int
        let minY: Int
        let maxX: Int
        let maxY: Int
    }

    private static func floodFill(
        start: (Int, Int),
        id: IslandID,
        grid: Grid,
        component: inout [Int]
    ) -> ComponentStats {
        var stack: [(Int, Int)] = [start]
        var tileCount = 0
        var minX = start.0, minY = start.1, maxX = start.0, maxY = start.1
        while let (px, py) = stack.popLast() {
            let pIdx = py * grid.width + px
            if component[pIdx] != -1 { continue }
            if !buildableTile(grid.terrain[pIdx]) { continue }
            component[pIdx] = Int(id)
            tileCount &+= 1
            minX = min(minX, px); minY = min(minY, py)
            maxX = max(maxX, px); maxY = max(maxY, py)
            if px > 0 { stack.append((px - 1, py)) }
            if px < grid.width - 1 { stack.append((px + 1, py)) }
            if py > 0 { stack.append((px, py - 1)) }
            if py < grid.height - 1 { stack.append((px, py + 1)) }
        }
        return ComponentStats(
            tileCount: tileCount,
            minX: minX, minY: minY, maxX: maxX, maxY: maxY
        )
    }

    private static func makeIsland(
        id: IslandID,
        stats: ComponentStats,
        mapHeightForClimate: Int,
        seed: UInt64,
        taken: Set<String>
    ) -> Island {
        let climate: Climate = (stats.minY + stats.maxY) / 2 < mapHeightForClimate / 2
            ? .temperate : .tropical
        let bounds = TileBoundingBox(
            minX: stats.minX,
            minY: stats.minY,
            maxX: stats.maxX,
            maxY: stats.maxY
        )
        return Island(
            id: id,
            tileCount: stats.tileCount,
            bounds: bounds,
            climate: climate,
            name: IslandNameTable.pick(seed: seed, bounds: bounds, id: id, taken: taken)
        )
    }

    private static func makeTileMap(
        width: Int, height: Int, component: [Int]
    ) -> [TileCoordinate: IslandID] {
        var tileToIsland: [TileCoordinate: IslandID] = [:]
        tileToIsland.reserveCapacity(width * height / 2)
        for tileY in 0 ..< height {
            for tileX in 0 ..< width {
                let value = component[tileY * width + tileX]
                guard value > 0 else { continue }
                tileToIsland[TileCoordinate(x: tileX, y: tileY)] = IslandID(value)
            }
        }
        return tileToIsland
    }
}
