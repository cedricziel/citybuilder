import Foundation

/// Headless simulation runner backing the `citybuilder-cli` tool and
/// integration tests. Loads a save (or starts a fresh world), advances N
/// ticks, and reports a summary. Per design D13's "Headless runner"
/// requirement and spec `simulation-core` ("CLI runner steps simulation").
public enum HeadlessRunner {
    public struct Summary: Sendable, Equatable {
        public let tickCount: UInt64
        public let simulatedTime: SimulationDuration
        public let mapWidth: Int
        public let mapHeight: Int

        public init(tickCount: UInt64, simulatedTime: SimulationDuration, mapWidth: Int, mapHeight: Int) {
            self.tickCount = tickCount
            self.simulatedTime = simulatedTime
            self.mapWidth = mapWidth
            self.mapHeight = mapHeight
        }
    }

    public enum RunError: Error, Equatable, CustomStringConvertible {
        case loadFailed(path: String, underlying: String)
        case negativeTicks(value: Int)

        public var description: String {
            switch self {
            case let .loadFailed(path, underlying):
                "could not load save '\(path)': \(underlying)"
            case let .negativeTicks(value):
                "ticks must be non-negative (got \(value))"
            }
        }
    }

    /// Run the simulation for `ticks` ticks, optionally starting from a saved
    /// world at `loadFrom`. When `loadFrom` is nil, the world starts as a
    /// fresh `World.newGame()`.
    public static func run(loadFrom path: String?, ticks: Int) throws -> Summary {
        guard ticks >= 0 else { throw RunError.negativeTicks(value: ticks) }

        var world = try loadWorld(from: path)
        for _ in 0 ..< ticks {
            world.tick()
        }
        return Summary(
            tickCount: world.tickCount,
            simulatedTime: world.simulatedTime,
            mapWidth: world.mapWidth,
            mapHeight: world.mapHeight
        )
    }

    private static func loadWorld(from path: String?) throws -> World {
        guard let path else { return World.newGame() }
        do {
            let url = URL(fileURLWithPath: path)
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(World.self, from: data)
        } catch {
            throw RunError.loadFailed(path: path, underlying: "\(error)")
        }
    }
}
