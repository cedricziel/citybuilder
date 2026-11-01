import Foundation

/// What happened to one good in the player's town during one season.
/// Spec: `statistics` / Goods flows are recorded per good.
public struct GoodFlow: Codable, Hashable, Sendable {
    public internal(set) var made = 0
    public internal(set) var usedByHouses = 0
    /// Recipe inputs and fuel.
    public internal(set) var usedByProduction = 0
    public internal(set) var usedByConstruction = 0
    public internal(set) var sold = 0
    public internal(set) var bought = 0
    /// Units in the player's goods buffers when the season closed.
    public internal(set) var stored = 0
    /// Samples in which a producer was stopped with this good stuck.
    public internal(set) var stuckSamples = 0

    public init() {}

    public var used: Int {
        usedByHouses + usedByProduction + usedByConstruction
    }

    /// What reached the stores and stayed there: made and bought, less what
    /// production and building used and the market sold. The houses' share
    /// counts, since the player can divert it. Negative in a season that
    /// drew on its stock. Spec: `orders` / Order size follows the town's output.
    var spare: Int {
        made + bought - usedByProduction - usedByConstruction - sold
    }

    /// Nothing made, used, sold, bought, stored or stuck.
    public var isEmpty: Bool {
        self == GoodFlow()
    }
}

/// Money in and out of the player's purse during one season.
public struct MoneyFlow: Codable, Hashable, Sendable {
    public internal(set) var tax: Int64 = 0
    public internal(set) var upkeep: Int64 = 0
    public internal(set) var tradeIncome: Int64 = 0
    public internal(set) var tradeSpending: Int64 = 0
    /// The balance when the season closed.
    public internal(set) var balance: Int64 = 0

    public init() {}
}

/// How often a kind's producers were in each state, counted in samples
/// (one per producer every `World.statisticsSampleTicks`).
public struct ProducerActivity: Codable, Hashable, Sendable {
    public internal(set) var working = 0
    public internal(set) var waiting = 0
    /// Stalled because the output has nowhere to go.
    public internal(set) var stuck = 0
    public internal(set) var blocked = 0

    public init() {}

    public var total: Int {
        working + waiting + stuck + blocked
    }
}

/// A rival town at the end of a season.
public struct RivalStatistics: Codable, Hashable, Sendable {
    public let id: RivalID
    public let residents: Int
    public let age: Age
    public let treasury: Int64

    public init(id: RivalID, residents: Int, age: Age, treasury: Int64) {
        self.id = id
        self.residents = residents
        self.age = age
        self.treasury = treasury
    }
}

/// One season of the player's town. Maps are sparse: a good, producer
/// kind or tier with nothing to report is absent.
public struct SeasonStatistics: Codable, Hashable, Sendable {
    /// The season's number since the start of the game (tick / 600).
    public internal(set) var season = 0
    public internal(set) var goods: [Good: GoodFlow] = [:]
    public internal(set) var money = MoneyFlow()
    public internal(set) var residents: [HouseTier: Int] = [:]
    public internal(set) var producers: [BuildingKind: ProducerActivity] = [:]
    public internal(set) var rivals: [RivalStatistics] = []
    /// The player's age when the season closed.
    public internal(set) var age: Age = .medieval
    /// What the player's goods buffers could hold of one good when the
    /// season closed: the sum of their stockpiles' capacities. Pooled
    /// stores share this between goods; per-good stores limit each good
    /// to it.
    public internal(set) var storeCapacity = 0

    public init() {}
}

/// The last 40 finished seasons and the one in progress. Spec:
/// `statistics` / The world keeps a bounded history of seasons.
public struct StatisticsHistory: Codable, Hashable, Sendable {
    public static let capacity = 40

    /// Oldest first.
    public internal(set) var seasons: [SeasonStatistics] = []
    public internal(set) var current = SeasonStatistics()

    public init() {}

    mutating func close(_ record: SeasonStatistics) {
        seasons.append(record)
        if seasons.count > Self.capacity {
            seasons.removeFirst(seasons.count - Self.capacity)
        }
        current = SeasonStatistics()
    }
}

extension KeyedDecodingContainer {
    /// Saves written before the statistics screen have no history; they
    /// start recording at the next tick. `World`'s synthesized decoder
    /// picks this overload for its `statistics` field.
    func decode(_ type: StatisticsHistory.Type, forKey key: Key) throws -> StatisticsHistory {
        try decodeIfPresent(type, forKey: key) ?? StatisticsHistory()
    }
}
