import CityCore
import Foundation

/// Headless model of the Statistics sheet: the world's season history
/// turned into the series the charts draw. Spec: `statistics` / The
/// Statistics sheet.
public struct StatisticsModel: Equatable, Sendable {
    public enum Tab: String, CaseIterable, Identifiable, Sendable {
        case goods, money, people, rivals

        public var id: String {
            rawValue
        }

        public var title: String {
            rawValue.prefix(1).uppercased() + rawValue.dropFirst()
        }
    }

    /// One value of a series, at the season it belongs to.
    public struct Point: Equatable, Identifiable, Sendable {
        public let season: Int
        public let value: Int

        public var id: Int {
            season
        }
    }

    public struct GoodRow: Equatable, Identifiable, Sendable {
        public let good: Good
        public let name: String
        /// Made minus used in the latest season.
        public let net: Int
        /// Producers stopped now with this good stuck.
        public let stoppedNow: Int
        public let made: [Point]
        public let used: [Point]

        public var id: Good {
            good
        }
    }

    /// Where a kind's producers spent the latest season, as fractions of
    /// its samples.
    public struct ProducerShare: Equatable, Identifiable, Sendable {
        public let kind: BuildingKind
        public let name: String
        public let working: Double
        public let waiting: Double
        public let stuck: Double
        public let blocked: Double

        public var id: BuildingKind {
            kind
        }
    }

    public struct GoodDetail: Equatable, Sendable {
        public let row: GoodRow
        public let latestSold: Int
        public let latestBought: Int
        public let latestStored: Int
        public let stored: [Point]
        /// The fraction of the season (0 to 1) the good's producers
        /// were stopped with it stuck, per season.
        public let stuckShare: [Double]
        public let producers: [ProducerShare]
    }

    public struct Series: Equatable, Identifiable, Sendable {
        public let name: String
        public let points: [Point]

        public var id: String {
            name
        }
    }

    public struct RivalRow: Equatable, Identifiable, Sendable {
        public let name: String
        public let colourHex: String
        public let residents: Int
        public let age: String
        public let wealth: String

        public var id: String {
            name
        }
    }

    private let seasons: [SeasonStatistics]
    private let calendar: CalendarState
    private let stuckNow: [Good: Int]
    private let rivalNames: [RivalID: String]
    private let rivalColours: [RivalID: String]
    private let playerAge: Age
    private let locale: Locale

    public init(world: World, locale: Locale = .current) {
        self.init(
            seasons: world.statistics.seasons, calendar: world.calendar, stuckNow: world.stuckProducerCounts,
            rivals: Dictionary(uniqueKeysWithValues: world.rivals.map { ($0.id, ($0.name, $0.colour.hex)) }),
            playerAge: world.age, locale: locale
        )
    }

    init(
        seasons: [SeasonStatistics], calendar: CalendarState, stuckNow: [Good: Int] = [:],
        rivals: [RivalID: (name: String, colourHex: String)] = [:], playerAge: Age = .medieval,
        locale: Locale = .current
    ) {
        self.seasons = seasons
        self.calendar = calendar
        self.stuckNow = stuckNow
        rivalNames = rivals.mapValues(\.name)
        rivalColours = rivals.mapValues(\.colourHex)
        self.playerAge = playerAge
        self.locale = locale
    }

    /// Rivals appear only in a world that has them.
    public var tabs: [Tab] {
        rivalNames.isEmpty ? [.goods, .money, .people] : Tab.allCases
    }

    /// Before the first season closes there is nothing to draw.
    public var isEmpty: Bool {
        seasons.isEmpty
    }

    /// Producers stopped now, across all goods.
    public var stoppedProducersNow: Int {
        stuckNow.values.reduce(0, +)
    }

    /// "Spring 1203", for a season number.
    public func title(ofSeason season: Int) -> String {
        calendar.date(atTick: UInt64(season) * CalendarState.ticksPerSeason).displayText
    }

    /// The year on the axis at the start of a year, nothing between.
    public func axisLabel(ofSeason season: Int) -> String {
        let date = calendar.date(atTick: UInt64(season) * CalendarState.ticksPerSeason)
        return date.season == .spring ? "\(date.year)" : ""
    }

    private func points(_ value: (SeasonStatistics) -> Int) -> [Point] {
        seasons.map { Point(season: $0.season, value: value($0)) }
    }

    // MARK: Goods

    /// Goods with any number in the history, in catalog order.
    public var goods: [GoodRow] {
        Good.allCases.compactMap { good in
            let active = seasons.contains { !($0.goods[good] ?? GoodFlow()).isEmpty }
            return active ? row(for: good) : nil
        }
    }

    private func row(for good: Good) -> GoodRow {
        let latest = seasons.last?.goods[good]
        return GoodRow(
            good: good, name: GoodsCatalog.spec(for: good).displayName,
            net: (latest?.made ?? 0) - (latest?.used ?? 0), stoppedNow: stuckNow[good] ?? 0,
            made: points { $0.goods[good]?.made ?? 0 }, used: points { $0.goods[good]?.used ?? 0 }
        )
    }

    public func detail(of good: Good) -> GoodDetail {
        let latest = seasons.last
        let makers = BuildingKind.allCases.filter { ProductionCatalog.recipe(for: $0)?.outputs[good] != nil }
        let samples = seasons.map { season in
            makers.reduce(0) { $0 + (season.producers[$1]?.total ?? 0) }
        }
        let stuckShare = zip(seasons, samples).map { season, total in
            total == 0 ? 0 : Double(season.goods[good]?.stuckSamples ?? 0) / Double(total)
        }
        return GoodDetail(
            row: row(for: good), latestSold: latest?.goods[good]?.sold ?? 0,
            latestBought: latest?.goods[good]?.bought ?? 0, latestStored: latest?.goods[good]?.stored ?? 0,
            stored: points { $0.goods[good]?.stored ?? 0 }, stuckShare: stuckShare,
            producers: makers.compactMap { share(of: $0, in: latest) }
        )
    }

    private func share(of kind: BuildingKind, in season: SeasonStatistics?) -> ProducerShare? {
        guard let activity = season?.producers[kind], activity.total > 0 else { return nil }
        let total = Double(activity.total)
        return ProducerShare(
            kind: kind, name: kind.displayName, working: Double(activity.working) / total,
            waiting: Double(activity.waiting) / total, stuck: Double(activity.stuck) / total,
            blocked: Double(activity.blocked) / total
        )
    }

    // MARK: Money

    /// Tax and trade income, which draw above the axis.
    public var income: [Series] {
        [
            Series(name: "Tax", points: points { Int($0.money.tax) }),
            Series(name: "Trade", points: points { Int($0.money.tradeIncome) })
        ]
    }

    /// Upkeep and trade spending as negative values, which draw below the axis.
    public var spending: [Series] {
        [
            Series(name: "Upkeep", points: points { -Int($0.money.upkeep) }),
            Series(name: "Bought", points: points { -Int($0.money.tradeSpending) })
        ]
    }

    public var balance: [Point] {
        points { Int($0.money.balance) }
    }

    // MARK: People

    /// Residents per tier, lowest tier first; a tier never reached is left out.
    public var tiers: [Series] {
        HouseTier.allCases.compactMap { tier in
            guard seasons.contains(where: { ($0.residents[tier] ?? 0) > 0 }) else { return nil }
            return Series(name: tier.displayName, points: points { $0.residents[tier] ?? 0 })
        }
    }

    // MARK: Rivals

    /// Residents per town: "You" first, then each rival by ID.
    public var residentLines: [Series] {
        let you = Series(name: "You", points: points { $0.residents.values.reduce(0, +) })
        let others = rivalNames.keys.sorted().map { id in
            Series(name: rivalNames[id] ?? "", points: points { season in
                season.rivals.first { $0.id == id }?.residents ?? 0
            })
        }
        return [you] + others
    }

    /// Colour of each line in `residentLines`, as "#RRGGBB".
    public var residentLineColours: [String] {
        [RivalColour.playerHex] + rivalNames.keys.sorted().map { rivalColours[$0] ?? RivalColour.playerHex }
    }

    /// The latest season's standings.
    public var standings: [RivalRow] {
        guard let latest = seasons.last else { return [] }
        let you = RivalRow(
            name: "You", colourHex: RivalColour.playerHex, residents: latest.residents.values.reduce(0, +),
            age: playerAge.displayName, wealth: HUDViewModel.formatMoney(latest.money.balance, locale: locale)
        )
        let others = latest.rivals.map { rival in
            RivalRow(
                name: rivalNames[rival.id] ?? "", colourHex: rivalColours[rival.id] ?? RivalColour.playerHex,
                residents: rival.residents, age: rival.age.displayName,
                wealth: HUDViewModel.formatMoney(rival.treasury, locale: locale)
            )
        }
        return [you] + others
    }
}
