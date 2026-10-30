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

    /// A label per road tile, equal for two tiles exactly when a road path
    /// joins them. The label values carry no meaning beyond equality, so
    /// the set's iteration order cannot leak into the simulation.
    public func componentLabels() -> [TileCoordinate: Int] {
        var labels: [TileCoordinate: Int] = [:]
        labels.reserveCapacity(roadTiles.count)
        var next = 0
        for seed in roadTiles where labels[seed] == nil {
            var stack = [seed]
            labels[seed] = next
            while let tile = stack.popLast() {
                for neighbor in adjacency[tile] ?? [] where labels[neighbor] == nil {
                    labels[neighbor] = next
                    stack.append(neighbor)
                }
            }
            next += 1
        }
        return labels
    }

    /// Road distance from the nearest of `sources` to every road tile at most `limit` tiles away, by
    /// breadth-first search. `isRoad`, when given, decides which tiles count as road instead of the graph,
    /// so a plan can measure roads it has not laid yet.
    func distances(
        from sources: [TileCoordinate], upTo limit: Int, isRoad: ((TileCoordinate) -> Bool)? = nil
    ) -> [TileCoordinate: Int] {
        var distances: [TileCoordinate: Int] = [:]
        var frontier: [TileCoordinate] = []
        for source in sources where distances[source] == nil {
            distances[source] = 0
            frontier.append(source)
        }
        var next: [TileCoordinate] = []
        var distance = 0
        while !frontier.isEmpty, distance < limit {
            distance += 1
            for tile in frontier {
                for neighbor in roadNeighbors(of: tile, isRoad: isRoad) where distances[neighbor] == nil {
                    distances[neighbor] = distance
                    next.append(neighbor)
                }
            }
            swap(&frontier, &next)
            next.removeAll(keepingCapacity: true)
        }
        return distances
    }

    /// A shortest road path from the nearest of `sources` to `goal`, read back from `distances` (the
    /// result of `distances(from: sources, …)`). Each step back takes the lowest neighbour by row, then
    /// column, so the path never depends on set order.
    func path(to goal: TileCoordinate, along distances: [TileCoordinate: Int]) -> [TileCoordinate]? {
        guard var step = distances[goal] else { return nil }
        var path = [goal]
        var tile = goal
        while step > 0 {
            let back = roadNeighbors(of: tile, isRoad: nil)
                .filter { distances[$0] == step - 1 }
                .min { ($0.y, $0.x) < ($1.y, $1.x) }
            guard let back else { return nil }
            path.append(back)
            tile = back
            step -= 1
        }
        return path.reversed()
    }

    private func roadNeighbors(of tile: TileCoordinate, isRoad: ((TileCoordinate) -> Bool)?) -> [TileCoordinate] {
        guard let isRoad else { return Array(adjacency[tile] ?? []) }
        return neighbors(of: tile).filter(isRoad)
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
