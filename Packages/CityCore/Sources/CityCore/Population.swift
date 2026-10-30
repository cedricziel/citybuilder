import Foundation

/// Population tier of a house. Spec: `population-and-needs` / Houses
/// have a population tier. Cases, capacity, needs, tax and names are
/// generated from the packs; raw values are the tiers' load order.
extension HouseTier: Comparable {
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
    /// Consecutive consumption intervals each good has been drawn short;
    /// a good drawn in full has no entry. Spec: `population-and-needs` /
    /// Houses decline only after a grace period.
    public private(set) var shortIntervals: [Good: UInt8] = [:]
    /// Units of each need the house holds, delivered by market porters and
    /// eaten at consumption. Spec: `population-and-needs` / Houses consume
    /// food and planks (visible-distribution design D4).
    public private(set) var stock: [Good: Int] = [:]

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
        tier.needs(in: culture).contains(good) ? Self.amount(of: good, residents: population) : 0
    }

    /// Amount of a needed `good` that `residents` eat per interval; a need
    /// without its own rate is eaten one per eight residents.
    static func amount(of good: Good, residents: UInt32) -> Int {
        switch good {
        case .food: Int((residents + 1) / 2)
        case .planks: 1
        case .bread: Int((residents + 3) / 4)
        default: Int((residents + 7) / 8)
        }
    }

    /// What `good` takes per interval once someone lives here: a house
    /// with no residents is stocked for its first.
    public func nextConsumption(of good: Good) -> Int {
        Self.amount(of: good, residents: max(population, 1))
    }

    /// Units of `good` the house's stock holds at most: two consumptions,
    /// and at least the minimum (game data).
    public func stockCapacity(of good: Good) -> Int {
        max(LogisticsCatalog.houseStockMinimum, LogisticsCatalog.houseStockConsumptions * nextConsumption(of: good))
    }

    /// Units of `good` in the house's stock.
    public func stock(of good: Good) -> Int {
        stock[good] ?? 0
    }

    /// Puts up to `amount` of `good` into the stock, as far as its
    /// capacity allows. Returns the units taken.
    @discardableResult
    mutating func addStock(_ good: Good, amount: Int) -> Int {
        let taken = max(0, min(amount, stockCapacity(of: good) - stock(of: good)))
        if taken > 0 { stock[good] = stock(of: good) + taken }
        return taken
    }

    /// Takes up to `amount` of `good` from the stock. Returns the units taken.
    mutating func takeStock(_ good: Good, amount: Int) -> Int {
        let taken = min(amount, stock(of: good))
        let left = stock(of: good) - taken
        stock[good] = left == 0 ? nil : left
        return taken
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

    /// Consumption intervals in a row `good` has been short.
    public func shortIntervals(of good: Good) -> Int {
        Int(shortIntervals[good] ?? 0)
    }

    /// One consumption of `good`: a short draw extends its run, a full
    /// one ends it.
    public mutating func recordConsumption(of good: Good, short: Bool) {
        setShort(good, short)
        shortIntervals[good] = short ? min(shortIntervals[good, default: 0], .max - 1) + 1 : nil
    }

    /// Forgets the runs of goods `needs` does not list.
    mutating func keepShortIntervals(for needs: [Good]) {
        shortIntervals = shortIntervals.filter { needs.contains($0.key) }
    }

    /// Forgets the runs and short flags of goods a tier the house has
    /// left needed; no later draw would clear them.
    mutating func keepShortages(for needs: [Good]) {
        keepShortIntervals(for: needs)
        shortGoods = shortGoods.filter { needs.contains($0) }
    }

    /// An empty house eats nothing, so nothing is short.
    mutating func clearShortages() {
        shortGoods.removeAll()
        shortIntervals.removeAll()
    }

    public init() {}

    /// True when every need of the current tier in `culture` is met.
    public func allNeedsSatisfied(in culture: Culture) -> Bool {
        tier.needs(in: culture).allSatisfy(isSatisfied)
    }
}

extension HousePopulation: Codable {
    private enum CodingKeys: String, CodingKey {
        case population, tier, satisfiedGoods, shortGoods, shortIntervals
        case ticksAtCurrentSatisfaction, ticksAtTierCondition, stock
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

    /// One good's units in the house stock, as saved.
    private struct StockEntry: Codable {
        let good: Good
        let units: Int
    }

    /// One good's run of short intervals, as saved.
    private struct ShortRun: Codable {
        let good: Good
        let intervals: UInt8
    }

    /// Older saves lack tier and timing keys and store satisfaction as
    /// per-good flags; missing values decode as peasants that are not
    /// short of anything. A save without runs starts one interval for each
    /// good the house is short of, so its grace begins on load.
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
        let runs = try container.decodeIfPresent([ShortRun].self, forKey: .shortIntervals)
            ?? shortGoods.map { ShortRun(good: $0, intervals: 1) }
        shortIntervals = Dictionary(runs.map { ($0.good, $0.intervals) }, uniquingKeysWith: { $1 })
        // A save from before market porters holds no stock: each need the
        // house counts as met gets one consumption, so it is not short at
        // the first draw after loading (design D6).
        let entries = try container.decodeIfPresent([StockEntry].self, forKey: .stock)
            ?? satisfiedGoods.sortedByRawValue.map { StockEntry(good: $0, units: Self.amount(of: $0, residents: max(population, 1))) }
        stock = Dictionary(entries.filter { $0.units > 0 }.map { ($0.good, $0.units) }, uniquingKeysWith: { $1 })
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(population, forKey: .population)
        try container.encode(tier, forKey: .tier)
        try container.encode(satisfiedGoods.sortedByRawValue, forKey: .satisfiedGoods)
        try container.encode(ticksAtCurrentSatisfaction, forKey: .ticksAtCurrentSatisfaction)
        try container.encode(ticksAtTierCondition, forKey: .ticksAtTierCondition)
        try container.encode(shortGoods.sortedByRawValue, forKey: .shortGoods)
        let runs = shortIntervals.sorted { $0.key.rawValue < $1.key.rawValue }.map { ShortRun(good: $0.key, intervals: $0.value) }
        try container.encode(runs, forKey: .shortIntervals)
        let entries = stock.sorted { $0.key.rawValue < $1.key.rawValue }.map { StockEntry(good: $0.key, units: $0.value) }
        try container.encode(entries, forKey: .stock)
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
