import Foundation

/// Remembers recent tile-to-island maps. Islands are the connected
/// components of buildable tiles, so a map stays valid while the
/// buildable mask is unchanged; forest clearing never invalidates it.
/// Process-wide rather than a field on `World` so the world's
/// synthesized `Codable` and `Equatable` (and the save format) stay as
/// they are.
///
/// Each entry remembers every recent terrain buffer known to share its
/// mask, so several live worlds with the same islands (parallel tests,
/// a snapshot beside the live world) all hit by buffer identity instead
/// of evicting one another and paying a full-map comparison per lookup.
final class IslandMapCache: @unchecked Sendable {
    static let shared = IslandMapCache()

    private struct Entry {
        /// Buffers known to share this entry's mask, newest last. The
        /// cache holds them, so their addresses can't be reused.
        var buffers: [[TerrainType]]
        let width: Int
        let map: [TileCoordinate: IslandID]

        func fits(width: Int, terrain: [TerrainType]) -> Bool {
            self.width == width && buffers[0].count == terrain.count
        }

        func holds(_ terrain: [TerrainType]) -> Bool {
            buffers.contains { IslandMapCache.sameBuffer($0, terrain) }
        }
    }

    private static let capacity = 8
    private static let buffersPerEntry = 8
    private let lock = NSLock()
    private var entries: [Entry] = []
    private var comparisons = 0

    /// Full buildable-mask comparisons so far, for tests.
    var maskComparisons: Int {
        lock.lock()
        defer { lock.unlock() }
        return comparisons
    }

    func map(width: Int, height: Int, terrain: [TerrainType]) -> [TileCoordinate: IslandID] {
        if let hit = cachedMap(width: width, terrain: terrain) {
            return hit
        }
        // The per-tile map depends on neither the seed nor the climate
        // inputs; those only shape the discarded island list.
        let map = IslandDetector.detect(
            width: width, height: height, terrain: terrain, mapHeightForClimate: height, seed: 0
        ).tileToIsland
        // Another thread may have added the same mask meanwhile.
        if let hit = cachedMap(width: width, terrain: terrain) {
            return hit
        }
        lock.lock()
        defer { lock.unlock() }
        entries.append(Entry(buffers: [terrain], width: width, map: map))
        if entries.count > Self.capacity {
            entries.removeFirst()
        }
        return map
    }

    /// A hit moves to the most-recent end. A mask match adopts the new
    /// buffer, so its next lookup hits by identity.
    private func cachedMap(width: Int, terrain: [TerrainType]) -> [TileCoordinate: IslandID]? {
        lock.lock()
        defer { lock.unlock() }
        let byBuffer = entries.lastIndex { $0.fits(width: width, terrain: terrain) && $0.holds(terrain) }
        if let byBuffer {
            return touch(byBuffer)
        }
        for index in entries.indices.reversed() where entries[index].fits(width: width, terrain: terrain) {
            comparisons += 1
            guard Self.sameBuildableMask(entries[index].buffers[0], terrain) else { continue }
            entries[index].buffers.append(terrain)
            if entries[index].buffers.count > Self.buffersPerEntry {
                entries[index].buffers.removeFirst()
            }
            return touch(index)
        }
        return nil
    }

    private func touch(_ index: Int) -> [TileCoordinate: IslandID] {
        if index != entries.count - 1 {
            entries.append(entries.remove(at: index))
        }
        return entries[entries.count - 1].map
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
