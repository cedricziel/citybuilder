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
        case .merchants: [.food, .planks, .bread, .tools]
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
public struct HousePopulation: Hashable, Sendable {
    public var population: UInt32 = 0
    public var tier: HouseTier = .peasants
    /// Needs currently met. Spec: `population-and-needs` (design D2).
    public private(set) var satisfiedGoods: Set<Good> = [.planks]
    public var ticksAtCurrentSatisfaction: UInt64 = 0
    /// Consecutive ticks the house has qualified to move up (or down)
    /// a tier. Spec: `population-and-needs` / Houses advance and
    /// decline between tiers.
    public var ticksAtTierCondition: UInt64 = 0
    /// Goods the last consumption could not draw in full; a good leaves
    /// the set with the next consumption of it that succeeds.
    public private(set) var shortGoods: Set<Good> = []

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
    public func consumption(of good: Good, in culture: Culture) -> Int {
        guard tier.needs(in: culture).contains(good) else { return 0 }
        switch good {
        case .food: return Int((population + 1) / 2)
        case .planks: return 1
        case .bread: return Int((population + 3) / 4)
        case .tools, .beer, .wine, .tea, .coffee: return Int((population + 7) / 8)
        default: return 0
        }
    }

    public func isSatisfied(_ good: Good) -> Bool {
        satisfiedGoods.contains(good)
    }

    public mutating func setSatisfied(_ good: Good, _ value: Bool) {
        satisfiedGoods.set(good, value)
    }

    public func isShort(_ good: Good) -> Bool {
        shortGoods.contains(good)
    }

    public mutating func setShort(_ good: Good, _ value: Bool) {
        shortGoods.set(good, value)
    }

    public init() {}

    /// True when every need of the current tier in `culture` is met.
    public func allNeedsSatisfied(in culture: Culture) -> Bool {
        tier.needs(in: culture).allSatisfy(isSatisfied)
    }
}

extension HousePopulation: Codable {
    private enum CodingKeys: String, CodingKey {
        case population, tier, satisfiedGoods, shortGoods
        case ticksAtCurrentSatisfaction, ticksAtTierCondition
    }

    /// Per-good flag keys written before design D2.
    private enum LegacyKey: String, CodingKey {
        case foodSatisfied, planksSatisfied, breadSatisfied, toolsSatisfied
        case foodShortfall, planksShortfall, breadShortfall, toolsShortfall

        static let satisfied: [(Self, Good)] = [
            (.foodSatisfied, .food), (.planksSatisfied, .planks),
            (.breadSatisfied, .bread), (.toolsSatisfied, .tools)
        ]
        static let shortfall: [(Self, Good)] = [
            (.foodShortfall, .food), (.planksShortfall, .planks),
            (.breadShortfall, .bread), (.toolsShortfall, .tools)
        ]
    }

    /// Older saves lack tier and timing keys and store satisfaction as
    /// per-good flags; missing values decode as peasants that are not
    /// short of anything.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        population = try container.decode(UInt32.self, forKey: .population)
        tier = try container.decodeIfPresent(HouseTier.self, forKey: .tier) ?? .peasants
        ticksAtCurrentSatisfaction = try container.decodeIfPresent(
            UInt64.self, forKey: .ticksAtCurrentSatisfaction
        ) ?? 0
        ticksAtTierCondition = try container.decodeIfPresent(UInt64.self, forKey: .ticksAtTierCondition) ?? 0
        let legacy = try decoder.container(keyedBy: LegacyKey.self)
        satisfiedGoods = try container.decodeIfPresent([Good].self, forKey: .satisfiedGoods).map(Set.init)
            ?? Self.decodeFlags(LegacyKey.satisfied, from: legacy)
        shortGoods = try container.decodeIfPresent([Good].self, forKey: .shortGoods).map(Set.init)
            ?? Self.decodeFlags(LegacyKey.shortfall, from: legacy)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(population, forKey: .population)
        try container.encode(tier, forKey: .tier)
        try container.encode(satisfiedGoods.sortedByRawValue, forKey: .satisfiedGoods)
        try container.encode(ticksAtCurrentSatisfaction, forKey: .ticksAtCurrentSatisfaction)
        try container.encode(ticksAtTierCondition, forKey: .ticksAtTierCondition)
        try container.encode(shortGoods.sortedByRawValue, forKey: .shortGoods)
    }

    private static func decodeFlags(
        _ keys: [(LegacyKey, Good)], from container: KeyedDecodingContainer<LegacyKey>
    ) throws -> Set<Good> {
        var result: Set<Good> = []
        for (key, good) in keys where try container.decodeIfPresent(Bool.self, forKey: key) == true {
            result.insert(good)
        }
        return result
    }
}

private extension Set {
    mutating func set(_ element: Element, _ isMember: Bool) {
        if isMember { insert(element) } else { remove(element) }
    }
}

private extension Set<Good> {
    /// Stable order so saves encode identically on every run.
    var sortedByRawValue: [Good] {
        sorted { $0.rawValue < $1.rawValue }
    }
}
