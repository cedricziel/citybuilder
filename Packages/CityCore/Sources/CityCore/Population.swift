import Foundation

/// Population tier of a house. Spec: `population-and-needs` / Houses
/// have a population tier.
public enum HouseTier: UInt8, Codable, Sendable, CaseIterable, Comparable {
    case peasants = 1
    case citizens = 2
    case merchants = 3

    public var capacity: UInt32 {
        switch self {
        case .peasants: 4
        case .citizens: 6
        case .merchants: 8
        }
    }

    /// Goods this tier needs, in catalog order.
    public var needs: [Good] {
        switch self {
        case .peasants: [.food]
        case .citizens: [.food, .planks]
        case .merchants: [.food, .planks, .bread]
        }
    }

    public var taxPerResident: Int64 {
        switch self {
        case .peasants: 1
        case .citizens: 2
        case .merchants: 4
        }
    }

    public var displayName: String {
        switch self {
        case .peasants: "Peasants"
        case .citizens: "Citizens"
        case .merchants: "Merchants"
        }
    }

    public var next: HouseTier? {
        HouseTier(rawValue: rawValue + 1)
    }

    public var previous: HouseTier? {
        HouseTier(rawValue: rawValue - 1)
    }

    public static func < (lhs: HouseTier, rhs: HouseTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Per-house population state.
public struct HousePopulation: Hashable, Codable, Sendable {
    public var population: UInt32 = 0
    public var tier: HouseTier = .peasants
    public var foodSatisfied: Bool = false
    public var planksSatisfied: Bool = true
    public var breadSatisfied: Bool = false
    public var ticksAtCurrentSatisfaction: UInt64 = 0
    /// Consecutive ticks the house has qualified to move up (or down)
    /// a tier. Spec: `population-and-needs` / Houses advance and
    /// decline between tiers.
    public var ticksAtTierCondition: UInt64 = 0
    /// Set when the last consumption could not draw the full amount;
    /// cleared by the next consumption that succeeds.
    public var foodShortfall: Bool = false
    public var planksShortfall: Bool = false
    public var breadShortfall: Bool = false

    public static let growthIntervalTicks: UInt64 = 60
    public static let declineIntervalTicks: UInt64 = 60
    public static let tierChangeTicks: UInt64 = 120
    /// Ticks between consumption. Spec: `population-and-needs` / Houses
    /// consume food and planks.
    public static let consumptionIntervalTicks: UInt64 = 100

    public var capacity: UInt32 {
        tier.capacity
    }

    /// Amount of `good` eaten per consumption interval at this tier.
    public func consumption(of good: Good) -> Int {
        guard tier.needs.contains(good) else { return 0 }
        switch good {
        case .food: return Int((population + 1) / 2)
        case .planks: return 1
        case .bread: return Int((population + 3) / 4)
        case .wood: return 0
        }
    }

    public func isSatisfied(_ good: Good) -> Bool {
        switch good {
        case .food: foodSatisfied
        case .planks: planksSatisfied
        case .bread: breadSatisfied
        case .wood: true
        }
    }

    public mutating func setSatisfied(_ good: Good, _ value: Bool) {
        switch good {
        case .food: foodSatisfied = value
        case .planks: planksSatisfied = value
        case .bread: breadSatisfied = value
        case .wood: break
        }
    }

    public func isShort(_ good: Good) -> Bool {
        switch good {
        case .food: foodShortfall
        case .planks: planksShortfall
        case .bread: breadShortfall
        case .wood: false
        }
    }

    public mutating func setShort(_ good: Good, _ value: Bool) {
        switch good {
        case .food: foodShortfall = value
        case .planks: planksShortfall = value
        case .bread: breadShortfall = value
        case .wood: break
        }
    }

    public init() {}

    private enum CodingKeys: String, CodingKey {
        case population, tier, foodSatisfied, planksSatisfied, breadSatisfied
        case ticksAtCurrentSatisfaction, ticksAtTierCondition
        case foodShortfall, planksShortfall, breadShortfall
    }

    /// Older saves lack tier, bread and shortfall keys; they decode as
    /// peasants that are not short of anything.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        population = try container.decode(UInt32.self, forKey: .population)
        tier = try container.decodeIfPresent(HouseTier.self, forKey: .tier) ?? .peasants
        foodSatisfied = try container.decode(Bool.self, forKey: .foodSatisfied)
        planksSatisfied = try container.decode(Bool.self, forKey: .planksSatisfied)
        breadSatisfied = try container.decodeIfPresent(Bool.self, forKey: .breadSatisfied) ?? false
        ticksAtCurrentSatisfaction = try container.decode(UInt64.self, forKey: .ticksAtCurrentSatisfaction)
        ticksAtTierCondition = try container.decodeIfPresent(UInt64.self, forKey: .ticksAtTierCondition) ?? 0
        foodShortfall = try container.decodeIfPresent(Bool.self, forKey: .foodShortfall) ?? false
        planksShortfall = try container.decodeIfPresent(Bool.self, forKey: .planksShortfall) ?? false
        breadShortfall = try container.decodeIfPresent(Bool.self, forKey: .breadShortfall) ?? false
    }

    /// True when every need of the current tier is met.
    public var allNeedsSatisfied: Bool {
        tier.needs.allSatisfy(isSatisfied)
    }
}
