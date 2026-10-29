import Foundation

/// What a chapter changes about the rules for the rest of the game: the
/// buildings and techs it closes and the earliest year rivals may enter an
/// age. Spec: `campaigns` / Chapter setup, Chapter build lists. Saves
/// without it decode the default (see the `KeyedDecodingContainer`
/// overload below): no chapter, nothing closed.
public struct ChapterRules: Codable, Hashable, Sendable {
    public internal(set) var chapterID: String?
    public internal(set) var closedBuildings: Set<BuildingKind>
    public internal(set) var closedTechs: Set<Tech>
    public internal(set) var rivalAgeYears: [Age: Int]

    public init(
        chapterID: String? = nil, closedBuildings: Set<BuildingKind> = [], closedTechs: Set<Tech> = [],
        rivalAgeYears: [Age: Int] = [:]
    ) {
        self.chapterID = chapterID
        self.closedBuildings = closedBuildings
        self.closedTechs = closedTechs
        self.rivalAgeYears = rivalAgeYears
    }
}

extension KeyedDecodingContainer {
    /// Saves written before chapters have none.
    func decode(_ type: ChapterRules.Type, forKey key: Key) throws -> ChapterRules {
        try decodeIfPresent(type, forKey: key) ?? ChapterRules()
    }
}

public extension ChapterStart {
    /// The Normal start scaled for `difficulty` (design D3): money ×1.5 on
    /// Easy and ×0.7 on Hard, rounded to the nearest $50; stock ×1.5 on
    /// Easy and ×0.5 on Hard, rounded up.
    func scaled(for difficulty: Difficulty) -> ChapterStart {
        let (numerator, stockNumerator): (Int64, Int) = switch difficulty {
        case .easy: (15, 15)
        case .normal: (10, 10)
        case .hard: (7, 5)
        }
        let money = (money * numerator + 250) / 500 * 50
        return ChapterStart(money: money, stock: stock.mapValues { ($0 * stockNumerator + 9) / 10 })
    }
}

public extension ChapterReward {
    /// `banner:Hearth`: how progress records the reward.
    var id: String {
        switch self {
        case let .banner(name): "banner:\(name)"
        case let .decor(name): "decor:\(name)"
        case let .mapPreset(name): "mapPreset:\(name)"
        }
    }
}

public extension Chapter {
    /// The start for `difficulty`: the scaled Normal start, with the
    /// chapter's override for that difficulty in place of either value.
    func start(for difficulty: Difficulty) -> ChapterStart {
        let scaled = start.scaled(for: difficulty)
        let override = overrides[difficulty]
        return ChapterStart(money: override?.money ?? scaled.money, stock: override?.stock ?? scaled.stock)
    }

    /// The rival age years for `difficulty`: its override, else the
    /// chapter's own.
    func rivalAgeYears(for difficulty: Difficulty) -> [Age: Int] {
        overrides[difficulty]?.rivalAgeYears ?? rivalAgeYears
    }

    /// On Easy each deadline falls a third of the chapter's span later,
    /// rounded up to a whole year.
    func loseConditions(for difficulty: Difficulty) -> [LoseCondition] {
        guard difficulty == .easy else { return loseConditions }
        return loseConditions.map { condition in
            guard case let .deadline(year) = condition else { return condition }
            let span = year - age.startYear
            return .deadline(year: year + (span + 2) / 3)
        }
    }
}

public extension World {
    /// A new game set up by a chapter at a difficulty. The chapter's
    /// culture wins over `culture`, the player's pick. The difficulty still
    /// sets upkeep, bankruptcy grace, research cost and event odds.
    static func newGame(chapter: Chapter, difficulty: Difficulty, culture: Culture) -> World {
        var world = newChapterMap(chapter, difficulty: difficulty, culture: chapter.culture ?? culture, rivals: chapter.rivals)
        let start = chapter.start(for: difficulty)
        world.economy.balance = start.money
        world.setStarterStock(start.stock)
        let researched = Set(world.research.researched + chapter.researched).subtracting(chapter.closedTechs)
        world.research = ResearchState(researched: Array(researched))
        world.goals = chapter.goals
        world.loseConditions = chapter.loseConditions(for: difficulty).map { LoseConditionState(condition: $0) }
        world.chapterRules = ChapterRules(
            chapterID: chapter.id, closedBuildings: chapter.closedBuildings, closedTechs: chapter.closedTechs,
            rivalAgeYears: chapter.rivalAgeYears(for: difficulty)
        )
        // Chapters never show the New Game toggle: events run when the
        // chapter schedules or draws them.
        world.seasonalEvents.enabled = !chapter.events.isEmpty || chapter.randomEvents
        world.seasonalEvents.randomEvents = chapter.randomEvents
        world.seasonalEvents.schedule = chapter.events
        return world
    }

    /// A sandbox game on a chapter's map: its layout, seed and terrain
    /// directives, with the sandbox's own difficulty, culture and rivals,
    /// and no goals. Spec: `campaigns` / Campaign rewards.
    static func newGame(
        mapPreset chapter: Chapter, difficulty: Difficulty, culture: Culture, rivals: Bool, seasonalEvents: Bool
    ) -> World {
        var world = newChapterMap(chapter, difficulty: difficulty, culture: culture, rivals: rivals ? nil : 0)
        world.seasonalEvents.enabled = seasonalEvents
        return world
    }

    private static func newChapterMap(_ chapter: Chapter, difficulty: Difficulty, culture: Culture, rivals: Int?) -> World {
        newGame(
            layout: chapter.layout, seed: chapter.seed, culture: culture, age: chapter.age, difficulty: difficulty,
            rivals: rivals != 0, directives: chapter.directives, rivalCount: rivals
        )
    }
}

extension World {
    /// Replaces each player town center's starting stock.
    mutating func setStarterStock(_ stock: [Good: Int]) {
        for center in buildings.values where center.kind == .townCenter && center.owner == .player {
            var pile = World.newStockpile(for: .townCenter) ?? Stockpile(capacity: 0)
            for (good, amount) in stock.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
                _ = pile.deposit(good, amount: amount)
            }
            stockpiles[center.id] = pile
        }
    }

    /// The earliest year a rival may enter `age` in this chapter.
    func rivalMayEnter(_ age: Age) -> Bool {
        chapterRules.rivalAgeYears[age].map { date.year >= $0 } ?? true
    }
}
