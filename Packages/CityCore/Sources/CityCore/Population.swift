import Foundation

/// Per-house population state.
public struct HousePopulation: Hashable, Codable, Sendable {
    public var population: UInt32 = 0
    public var foodSatisfied: Bool = false
    public var planksSatisfied: Bool = true
    public var ticksAtCurrentSatisfaction: UInt64 = 0
    /// Set when the last consumption could not draw the full amount;
    /// cleared by the next consumption that succeeds.
    public var foodShortfall: Bool = false
    public var planksShortfall: Bool = false

    public static let capacity: UInt32 = 4
    public static let growthIntervalTicks: UInt64 = 60
    public static let declineIntervalTicks: UInt64 = 60
    /// Ticks between food and plank consumption. Spec:
    /// `population-and-needs` / Houses consume food and planks.
    public static let consumptionIntervalTicks: UInt64 = 100

    /// Food eaten per consumption interval: 1 per 2 residents, rounded up.
    public var foodPerInterval: Int {
        Int((population + 1) / 2)
    }

    public init() {}

    public var allNeedsSatisfied: Bool {
        foodSatisfied && planksSatisfied
    }
}
