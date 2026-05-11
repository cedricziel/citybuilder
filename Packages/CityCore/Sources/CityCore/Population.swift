import Foundation

/// Per-house population state.
public struct HousePopulation: Hashable, Codable, Sendable {
    public var population: UInt32 = 0
    public var foodSatisfied: Bool = false
    public var planksSatisfied: Bool = true
    public var ticksAtCurrentSatisfaction: UInt64 = 0

    public static let capacity: UInt32 = 4
    public static let growthIntervalTicks: UInt64 = 60
    public static let declineIntervalTicks: UInt64 = 60

    public init() {}

    public var allNeedsSatisfied: Bool {
        foodSatisfied && planksSatisfied
    }
}
