import Foundation

/// A* pathfinder over a RoadGraph. Pure: takes a graph and two endpoints,
/// returns an ordered path or nil. Determinism comes from a stable tie-break
/// (by raw coordinate components) when costs match.
public enum PathFinder {
    public static func path(
        from start: TileCoordinate,
        to goal: TileCoordinate,
        in graph: RoadGraph
    ) -> [TileCoordinate]? {
        guard graph.roadTiles.contains(start), graph.roadTiles.contains(goal) else {
            return nil
        }
        if start == goal { return [start] }

        var openSet: [TileCoordinate] = [start]
        var cameFrom: [TileCoordinate: TileCoordinate] = [:]
        var gScore: [TileCoordinate: Int] = [start: 0]
        var fScore: [TileCoordinate: Int] = [start: heuristic(start, goal)]

        while !openSet.isEmpty {
            // Pull lowest fScore (with deterministic tie-break).
            openSet.sort { lhs, rhs in
                let lhsScore = fScore[lhs] ?? Int.max
                let rhsScore = fScore[rhs] ?? Int.max
                if lhsScore != rhsScore { return lhsScore < rhsScore }
                if lhs.x != rhs.x { return lhs.x < rhs.x }
                return lhs.y < rhs.y
            }
            let current = openSet.removeFirst()
            if current == goal { return reconstruct(cameFrom, to: current) }

            // Neighbours in a fixed order: a `Set`'s order differs between
            // worlds, and the first of two equal routes wins.
            let linked = graph.adjacency[current] ?? []
            for (dx, dy) in [(-1, 0), (0, -1), (0, 1), (1, 0)] {
                let neighbor = TileCoordinate(x: current.x + dx, y: current.y + dy)
                guard linked.contains(neighbor) else { continue }
                let tentative = (gScore[current] ?? Int.max) + 1
                if tentative < gScore[neighbor] ?? Int.max {
                    cameFrom[neighbor] = current
                    gScore[neighbor] = tentative
                    fScore[neighbor] = tentative + heuristic(neighbor, goal)
                    if !openSet.contains(neighbor) { openSet.append(neighbor) }
                }
            }
        }
        return nil
    }

    private static func heuristic(_ from: TileCoordinate, _ goal: TileCoordinate) -> Int {
        abs(from.x - goal.x) + abs(from.y - goal.y)
    }

    private static func reconstruct(
        _ cameFrom: [TileCoordinate: TileCoordinate],
        to terminal: TileCoordinate
    ) -> [TileCoordinate] {
        var result = [terminal]
        var cursor = terminal
        while let prev = cameFrom[cursor] {
            result.append(prev)
            cursor = prev
        }
        return result.reversed()
    }
}

/// Light cache for path results keyed by (graph generation, start, goal).
/// Stored inside World so save/load picks up a fresh cache (cache is empty
/// after decode — desired: no stale paths survive a load).
public struct PathCache: Codable, Sendable, Equatable {
    public private(set) var generation: UInt64 = 0
    public private(set) var entries: [Key: [TileCoordinate]] = [:]

    public struct Key: Hashable, Codable, Sendable {
        public let start: TileCoordinate
        public let goal: TileCoordinate
    }

    public init() {}

    public mutating func invalidate(currentGeneration: UInt64) {
        if generation != currentGeneration {
            generation = currentGeneration
            entries.removeAll()
        }
    }

    public mutating func store(_ path: [TileCoordinate], for key: Key) {
        entries[key] = path
    }

    public func lookup(_ key: Key) -> [TileCoordinate]? {
        entries[key]
    }
}
