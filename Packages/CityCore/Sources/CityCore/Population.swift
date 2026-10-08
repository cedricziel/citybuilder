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

    private enum CodingKeys: String, CodingKey {
        case population, foodSatisfied, planksSatisfied, ticksAtCurrentSatisfaction
        case foodShortfall, planksShortfall
    }

    /// Saves written before consumption have no shortfall keys; they
    /// decode as "not short".
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        population = try container.decode(UInt32.self, forKey: .population)
        foodSatisfied = try container.decode(Bool.self, forKey: .foodSatisfied)
        planksSatisfied = try container.decode(Bool.self, forKey: .planksSatisfied)
        ticksAtCurrentSatisfaction = try container.decode(UInt64.self, forKey: .ticksAtCurrentSatisfaction)
        foodShortfall = try container.decodeIfPresent(Bool.self, forKey: .foodShortfall) ?? false
        planksShortfall = try container.decodeIfPresent(Bool.self, forKey: .planksShortfall) ?? false
    }

    public var allNeedsSatisfied: Bool {
        foodSatisfied && planksSatisfied
    }
}
