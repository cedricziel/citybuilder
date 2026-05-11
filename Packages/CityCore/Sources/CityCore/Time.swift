import Foundation

/// Duration of simulated time. Internally nanoseconds for arithmetic precision.
public struct SimulationDuration: Hashable, Codable, Sendable {
    public let nanoseconds: Int64

    public init(nanoseconds: Int64) {
        self.nanoseconds = nanoseconds
    }

    public static func milliseconds(_ value: Int64) -> SimulationDuration {
        SimulationDuration(nanoseconds: value * 1_000_000)
    }

    public static let tick = SimulationDuration.milliseconds(100)
    public static let zero = SimulationDuration(nanoseconds: 0)

    public static func + (lhs: SimulationDuration, rhs: SimulationDuration) -> SimulationDuration {
        SimulationDuration(nanoseconds: lhs.nanoseconds + rhs.nanoseconds)
    }

    public static func - (lhs: SimulationDuration, rhs: SimulationDuration) -> SimulationDuration {
        SimulationDuration(nanoseconds: lhs.nanoseconds - rhs.nanoseconds)
    }

    public static func += (lhs: inout SimulationDuration, rhs: SimulationDuration) {
        lhs = lhs + rhs
    }
}
