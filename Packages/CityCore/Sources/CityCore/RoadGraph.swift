import Foundation

/// Connectivity graph over road tiles. Updated incrementally as road tiles
/// are added and removed. Backed by a dictionary from tile to its
/// orthogonally-adjacent road neighbors so the spec scenarios about
/// "new road extends graph" and "removing road removes edges" can be
/// checked directly.
///
/// Pathfinding is in PathFinder; the cache lives here so road changes can
/// invalidate it cheaply.
public struct RoadGraph: Codable, Sendable, Equatable {
    public private(set) var roadTiles: Set<TileCoordinate> = []
    public private(set) var adjacency: [TileCoordinate: Set<TileCoordinate>] = [:]
    /// Token bumped on every structural change. PathFinder uses it as a
    /// cache key; downstream caches MUST be invalidated whenever this moves.
    public private(set) var generation: UInt64 = 0

    public init() {}

    public mutating func addRoad(at coord: TileCoordinate) {
        guard !roadTiles.contains(coord) else { return }
        roadTiles.insert(coord)
        adjacency[coord] = []
        for neighbor in neighbors(of: coord) where roadTiles.contains(neighbor) {
            adjacency[coord, default: []].insert(neighbor)
            adjacency[neighbor, default: []].insert(coord)
        }
        generation &+= 1
    }

    public mutating func removeRoad(at coord: TileCoordinate) {
        guard roadTiles.contains(coord) else { return }
        roadTiles.remove(coord)
        let neighbors = adjacency[coord] ?? []
        adjacency.removeValue(forKey: coord)
        for neighbor in neighbors {
            adjacency[neighbor]?.remove(coord)
        }
        generation &+= 1
    }

    public func isConnected(_ tile: TileCoordinate) -> Bool {
        roadTiles.contains(tile)
    }

    /// Returns true if `anchor` is orthogonally adjacent to a road tile.
    public func isAnchorRoadConnected(_ anchor: TileCoordinate, footprint: Footprint) -> Bool {
        let occupied = Set(footprint.tiles(anchor: anchor))
        for tile in occupied {
            for neighbor in neighbors(of: tile) {
                if occupied.contains(neighbor) { continue }
                if roadTiles.contains(neighbor) { return true }
            }
        }
        return false
    }

    private func neighbors(of coord: TileCoordinate) -> [TileCoordinate] {
        [
            TileCoordinate(x: coord.x + 1, y: coord.y),
            TileCoordinate(x: coord.x - 1, y: coord.y),
            TileCoordinate(x: coord.x, y: coord.y + 1),
            TileCoordinate(x: coord.x, y: coord.y - 1)
        ]
    }
}
