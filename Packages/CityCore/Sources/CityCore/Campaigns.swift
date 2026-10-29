import Foundation

/// An ordered list of chapters. Spec: `campaigns` / Campaigns and chapters
/// are game data. The catalog comes from the packs (`CampaignCatalog`).
public struct Campaign: Hashable, Sendable {
    public let id: String
    public let title: String
    /// Chapter IDs in play order.
    public let chapters: [String]
    /// The chapter whose win opens this campaign's first chapter; nil when
    /// it is open from the start.
    public let opensAfter: String?

    public init(id: String, title: String, chapters: [String], opensAfter: String? = nil) {
        self.id = id
        self.title = title
        self.chapters = chapters
        self.opensAfter = opensAfter
    }
}

/// Starting money and stock. Spec: `campaigns` / Chapter setup (design D3).
public struct ChapterStart: Hashable, Sendable {
    public let money: Int64
    public let stock: [Good: Int]

    public init(money: Int64, stock: [Good: Int]) {
        self.money = money
        self.stock = stock
    }
}

/// A difficulty's replacement for the scaled money or stock, or for the
/// chapter's rival age years.
public struct ChapterStartOverride: Hashable, Sendable {
    public let money: Int64?
    public let stock: [Good: Int]?
    public let rivalAgeYears: [Age: Int]?

    public init(money: Int64? = nil, stock: [Good: Int]? = nil, rivalAgeYears: [Age: Int]? = nil) {
        self.money = money
        self.stock = stock
        self.rivalAgeYears = rivalAgeYears
    }
}

/// An island a terrain directive names. Spec: `world-terrain` / Terrain
/// directives.
public enum IslandRef: Hashable, Codable, Sendable {
    /// The island of the player's home town center.
    case home
    /// The `rank`th largest island other than home, from 1; ties by lower
    /// island ID.
    case other(rank: Int)
}

/// A deterministic change to the terrain after generation.
public enum TerrainDirective: Hashable, Codable, Sendable {
    /// Keeps about `keepPercent` of the forest outside the starter grove.
    case thinForest(IslandRef, keepPercent: Int)
    /// Clears mountains within `radius` of the home town center.
    case pushMineOut(radius: Int)
    case noMountains(IslandRef)
    case raiseMineSite(IslandRef)
}

/// What winning a chapter for the first time grants.
public enum ChapterReward: Hashable, Sendable {
    case banner(String)
    case decor(String)
    case mapPreset(String)
}

/// How the PlayerBot sweep plays a chapter (design D10).
public struct ChapterSweep: Hashable, Sendable {
    public let firstSteps: Bool
    /// `careful` or `naive`; nil for no mid-game order.
    public let order: String?
    public let market: Bool
    public let kits: [String]

    public init(firstSteps: Bool = true, order: String? = nil, market: Bool = true, kits: [String] = []) {
        self.firstSteps = firstSteps
        self.order = order
        self.market = market
        self.kits = kits
    }
}

/// One chapter of a campaign. Spec: `campaigns` / Campaigns and chapters
/// are game data.
public struct Chapter: Hashable, Sendable {
    public let id: String
    public let title: String
    public let intro: String
    public let ending: String
    public let layout: WorldLayout
    public let seed: UInt64
    public let age: Age
    /// Nil when the player picks the culture.
    public let culture: Culture?
    public let rivals: Int
    /// The Normal start; Easy and Hard scale it (design D3).
    public let start: ChapterStart
    public let overrides: [Difficulty: ChapterStartOverride]
    public let directives: [TerrainDirective]
    public let closedBuildings: Set<BuildingKind>
    public let closedTechs: Set<Tech>
    /// Techs researched at the start, besides the age's own.
    public let researched: [Tech]
    /// Goals and bonus goals.
    public let goals: [GoalState]
    public let loseConditions: [LoseCondition]
    /// The earliest year a rival may enter each age.
    public let rivalAgeYears: [Age: Int]
    public let difficulties: [Difficulty]
    public let reward: ChapterReward
    public let sweep: ChapterSweep
    /// Shown but never opened until a later update ships it.
    public let comingLater: Bool
    public let events: [ScheduledSeasonalEvent]
    public let randomEvents: Bool

    public init(
        id: String, title: String, intro: String, ending: String,
        layout: WorldLayout, seed: UInt64, age: Age, culture: Culture? = nil, rivals: Int = 0,
        start: ChapterStart, overrides: [Difficulty: ChapterStartOverride] = [:],
        directives: [TerrainDirective] = [], closedBuildings: Set<BuildingKind> = [], closedTechs: Set<Tech> = [],
        researched: [Tech] = [], goals: [GoalState], loseConditions: [LoseCondition] = [],
        rivalAgeYears: [Age: Int] = [:], difficulties: [Difficulty] = Difficulty.allCases,
        reward: ChapterReward, sweep: ChapterSweep = ChapterSweep(), comingLater: Bool = false,
        events: [ScheduledSeasonalEvent] = [], randomEvents: Bool = true
    ) {
        self.id = id
        self.title = title
        self.intro = intro
        self.ending = ending
        self.layout = layout
        self.seed = seed
        self.age = age
        self.culture = culture
        self.rivals = rivals
        self.start = start
        self.overrides = overrides
        self.directives = directives
        self.closedBuildings = closedBuildings
        self.closedTechs = closedTechs
        self.researched = researched
        self.goals = goals
        self.loseConditions = loseConditions
        self.rivalAgeYears = rivalAgeYears
        self.difficulties = difficulties
        self.reward = reward
        self.sweep = sweep
        self.comingLater = comingLater
        self.events = events
        self.randomEvents = randomEvents
    }
}

public extension CampaignCatalog {
    static func chapter(_ id: String) -> Chapter? {
        chapters.first { $0.id == id }
    }

    static func campaign(_ id: String) -> Campaign? {
        campaigns.first { $0.id == id }
    }
}
