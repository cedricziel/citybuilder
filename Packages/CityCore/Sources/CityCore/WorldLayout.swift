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

    public init(id: IslandID, tileCount: Int, bounds: TileBoundingBox, climate: Climate) {
        self.id = id
        self.tileCount = tileCount
        self.bounds = bounds
        self.climate = climate
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
        width: Int, height: Int, terrain: [TerrainType], mapHeightForClimate: Int
    ) -> [Island] {
        guard width > 0, height > 0 else { return [] }
        var component = [Int](repeating: -1, count: width * height)
        var islands: [Island] = []
        var nextID: IslandID = 1
        for startY in 0 ..< height {
            for startX in 0 ..< width {
                let startIdx = startY * width + startX
                guard component[startIdx] == -1, buildableTile(terrain[startIdx])
                else { continue }
                let id = nextID
                nextID &+= 1
                var stack: [(Int, Int)] = [(startX, startY)]
                var tileCount = 0
                var minX = startX, minY = startY, maxX = startX, maxY = startY
                while let (px, py) = stack.popLast() {
                    let pIdx = py * width + px
                    if component[pIdx] != -1 { continue }
                    if !buildableTile(terrain[pIdx]) { continue }
                    component[pIdx] = Int(id)
                    tileCount &+= 1
                    minX = min(minX, px); minY = min(minY, py)
                    maxX = max(maxX, px); maxY = max(maxY, py)
                    if px > 0 { stack.append((px - 1, py)) }
                    if px < width - 1 { stack.append((px + 1, py)) }
                    if py > 0 { stack.append((px, py - 1)) }
                    if py < height - 1 { stack.append((px, py + 1)) }
                }
                let climate: Climate = (minY + maxY) / 2 < mapHeightForClimate / 2
                    ? .temperate : .tropical
                islands.append(Island(
                    id: id,
                    tileCount: tileCount,
                    bounds: TileBoundingBox(
                        minX: minX, minY: minY, maxX: maxX, maxY: maxY
                    ),
                    climate: climate
                ))
            }
        }
        return islands
    }
}
