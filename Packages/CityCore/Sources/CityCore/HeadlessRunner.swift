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

    public enum RunError: Error, Equatable {
        case loadFailed(path: String, underlying: String)
        case notImplemented
    }

    /// Run the simulation for `ticks` ticks, optionally starting from a saved
    /// world at `loadFrom`. M1 STUB until task 2.7 — currently always throws.
    public static func run(loadFrom path: String?, ticks: Int) throws -> Summary {
        _ = path
        _ = ticks
        throw RunError.notImplemented
    }
}
