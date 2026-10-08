import Foundation

/// Remembers recent tile-to-island maps. Islands are the connected
/// components of buildable tiles, so a map stays valid while the
/// buildable mask is unchanged; forest clearing never invalidates it.
/// Process-wide rather than a field on `World` so the world's
/// synthesized `Codable` and `Equatable` (and the save format) stay as
/// they are.
final class IslandMapCache: @unchecked Sendable {
    static let shared = IslandMapCache()

    private struct Entry {
        var terrain: [TerrainType]
        let width: Int
        let map: [TileCoordinate: IslandID]
    }

    private static let capacity = 4
    private let lock = NSLock()
    private var entries: [Entry] = []

    func map(width: Int, height: Int, terrain: [TerrainType]) -> [TileCoordinate: IslandID] {
        if let hit = cachedMap(width: width, terrain: terrain) {
            return hit
        }
        // The per-tile map depends on neither the seed nor the climate
        // inputs; those only shape the discarded island list.
        let map = IslandDetector.detect(
            width: width, height: height, terrain: terrain, mapHeightForClimate: height, seed: 0
        ).tileToIsland
        lock.lock()
        defer { lock.unlock() }
        entries.append(Entry(terrain: terrain, width: width, map: map))
        if entries.count > Self.capacity {
            entries.removeFirst()
        }
        return map
    }

    /// A hit moves to the most-recent end and keeps the newest terrain
    /// buffer, so the next lookup hits the identity check.
    private func cachedMap(width: Int, terrain: [TerrainType]) -> [TileCoordinate: IslandID]? {
        lock.lock()
        defer { lock.unlock() }
        let match = entries.firstIndex { entry in
            entry.width == width && entry.terrain.count == terrain.count
                && (Self.sameBuffer(entry.terrain, terrain) || Self.sameBuildableMask(entry.terrain, terrain))
        }
        guard let match else { return nil }
        var entry = entries.remove(at: match)
        entry.terrain = terrain
        entries.append(entry)
        return entry.map
    }

    private static func sameBuffer(_ lhs: [TerrainType], _ rhs: [TerrainType]) -> Bool {
        lhs.withUnsafeBufferPointer { left in
            rhs.withUnsafeBufferPointer { left.baseAddress == $0.baseAddress }
        }
    }

    private static func sameBuildableMask(_ lhs: [TerrainType], _ rhs: [TerrainType]) -> Bool {
        lhs.withUnsafeBufferPointer { left in
            rhs.withUnsafeBufferPointer { right in
                let buildable = IslandDetector.buildableTile
                return !(0 ..< left.count).contains { buildable(left[$0]) != buildable(right[$0]) }
            }
        }
    }
}
