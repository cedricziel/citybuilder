import GameDataModel
import Testing

// Scenarios from openspec/changes/add-campaigns (campaigns / Campaigns and
// chapters are game data) and add-event-counterplay (seasonal-events /
// Chapters schedule events).

private let chapterPack = """
items:
  - { kind: Campaign, id: chronicle, title: The Long Chronicle, chapters: [first-fires, the-crossing] }
  - { kind: Campaign, id: sea, title: The Merchant Sea, chapters: [two-shores], opensAfter: the-crossing }
  - kind: Event
    id: fire
    effect: fire
    seasons: [summer, autumn]
    weight: { easy: 1, normal: 1, hard: 2 }
    banners: { warning: { title: Dry, text: Fire risk. } }
  - kind: Chapter
    id: first-fires
    title: First Fires
    intro: Smoke rises from one hearth on an empty shore.
    ending: A village has taken root.
    layout: single-island
    seed: 101
    age: antiquity
    money: 1000
    stock: { wood: 6, planks: 5 }
    overrides: { hard: { money: 600 } }
    closedBuildings: [port]
    goals:
      - { buildings: house, count: 3 }
      - { residents: 24 }
      - { netIncome: 60 }
    bonus:
      - { treasury: 1200 }
      - { residents: 20, tier: citizens, hold: true }
    lose: { deadline: -496 }
    reward: { banner: Hearth }
    sweep: { firstSteps: true, market: true }
  - kind: Chapter
    id: the-crossing
    title: The Crossing
    intro: Two shores.
    ending: One town.
    layout: archipelago
    seed: 201
    age: medieval
    culture: northern-european
    rivals: 1
    money: 1500
    directives:
      - { thinForest: { island: home, keep: 15 } }
      - { pushMineOut: 16 }
      - { noMountains: 2 }
      - { raiseMineSite: home }
    researched: [seafaring]
    goals:
      - { stock: wood, count: 20 }
      - { landed: planks, count: 60 }
      - { age: medieval }
      - { research: cultivation }
      - { tradeEarnings: 400 }
      - { orders: 1 }
      - { signatureProjects: 1 }
      - { outgrowRivals: true }
    lose: { deadline: 1206, rivalRace: { age: medieval }, collapse: 40 }
    rivalAgeYears: { medieval: 1207 }
    reward: { mapPreset: The Crossing }
    events: [{ year: 1202, season: summer, event: fire }]
    randomEvents: false
  - kind: Chapter
    id: two-shores
    title: Two Shores
    intro: Across the strait.
    ending: Timber crosses.
    layout: archipelago
    seed: 301
    age: medieval
    rivals: 1
    money: 1500
    goals: [{ residents: 40 }]
    lose: { rivalRace: { residents: 60 } }
    reward: { decor: Press stone }
    comingLater: true
"""

private func errors(replacing old: String, with new: String) -> [String] {
    Fixtures.errors(Fixtures.withExtraPack(chapterPack.replacingOccurrences(of: old, with: new)))
}

@Test("campaigns and chapters load from a pack")
func campaignsAndChaptersLoad() throws {
    let data = try Fixtures.load(Fixtures.withExtraPack(chapterPack)).get()
    #expect(data.campaigns.map(\.id) == ["chronicle", "sea"])
    #expect(data.campaigns[1].opensAfter == "the-crossing")
    #expect(data.chapters.map(\.id) == ["first-fires", "the-crossing", "two-shores"])
    let first = data.chapters[0]
    #expect(first.goals.count == 3 && first.bonus.count == 2)
    let held = first.bonus[1]
    #expect(held.kind == "residents" && held.amount == 20 && held.tier == "citizens" && held.hold)
    #expect(first.overrides["hard"]?.money == 600)
    let crossing = data.chapters[1]
    #expect(crossing.directives.map(\.kind) == ["thinForest", "pushMineOut", "noMountains", "raiseMineSite"])
    #expect(crossing.race?.age == "medieval" && crossing.collapse == 40 && crossing.deadline == 1206)
    let event = try #require(crossing.events.first)
    #expect(event.year == 1202 && event.season == "summer" && event.event == "fire" && !crossing.randomEvents)
    #expect(data.chapters[2].comingLater)
}

@Test("scenario: unknown good in a goal is rejected")
func unknownGoodInAGoalIsRejected() {
    let found = errors(replacing: "{ stock: wood, count: 20 }", with: "{ stock: silk, count: 20 }")
    #expect(found.contains { $0.contains("Chapter the-crossing") && $0.contains("silk") }, "\(found)")
}

@Test("scenario: card text over the limit is rejected")
func cardTextOverTheLimitIsRejected() {
    let long = String(repeating: "a", count: 321)
    let found = errors(replacing: "intro: Two shores.", with: "intro: \(long)")
    #expect(found.contains { $0.contains("Chapter the-crossing") && $0.contains("321") }, "\(found)")
    let atLimit = errors(replacing: "intro: Two shores.", with: "intro: \(String(long.dropFirst()))")
    #expect(atLimit.isEmpty, "\(atLimit)")
}

@Test("a chapter with only bonus goals is rejected")
func aChapterWithOnlyBonusGoalsIsRejected() {
    let found = errors(replacing: "goals: [{ residents: 40 }]", with: "goals: []\n    bonus: [{ residents: 40 }]")
    #expect(found.contains { $0.contains("Chapter two-shores") && $0.contains("`goals`") }, "\(found)")
}

@Test("unknown names in a chapter are rejected and name the chapter")
func unknownNamesInAChapterAreRejected() {
    let found = errors(replacing: "{ buildings: house, count: 3 }", with: "{ buildings: castle, count: 3 }")
        + errors(replacing: "{ age: medieval }", with: "{ age: bronze }")
        + errors(replacing: "{ research: cultivation }", with: "{ research: alchemy }")
        + errors(replacing: "researched: [seafaring]", with: "researched: [alchemy]")
        + errors(replacing: "closedBuildings: [port]", with: "closedBuildings: [castle]")
        + errors(replacing: "culture: northern-european", with: "culture: atlantean")
        + errors(replacing: "tier: citizens, hold", with: "tier: nobles, hold")
    for name in ["castle", "bronze", "alchemy", "atlantean", "nobles"] {
        #expect(found.contains { $0.contains("Chapter") && $0.contains(name) }, "\(name): \(found)")
    }
}

@Test("scenario: two events in one year are rejected")
func twoEventsInOneYearAreRejected() {
    let found = errors(
        replacing: "events: [{ year: 1202, season: summer, event: fire }]",
        with: "events: [{ year: 1202, season: summer, event: fire }, { year: 1202, season: autumn, event: fire }]"
    )
    #expect(found.contains { $0.contains("Chapter the-crossing") && $0.contains("two events in 1202") }, "\(found)")
}

@Test("scenario: a scheduled hazard in spring is rejected")
func aScheduledHazardInSpringIsRejected() {
    let spring = errors(replacing: "season: summer, event: fire", with: "season: spring, event: fire")
    #expect(spring.contains { $0.contains("Chapter the-crossing") && $0.contains("spring") }, "\(spring)")
    let winter = errors(replacing: "season: summer, event: fire", with: "season: winter, event: fire")
    #expect(winter.contains { $0.contains("not one of its seasons") }, "\(winter)")
    let unknown = errors(replacing: "season: summer, event: fire", with: "season: summer, event: flood")
    #expect(unknown.contains { $0.contains("unknown event `flood`") }, "\(unknown)")
}

@Test("campaigns must list every chapter exactly once")
func campaignsListEveryChapterOnce() {
    let unlisted = errors(replacing: "chapters: [two-shores]", with: "chapters: [first-fires]")
    #expect(unlisted.contains { $0.contains("Chapter two-shores") && $0.contains("no campaign") }, "\(unlisted)")
    #expect(unlisted.contains { $0.contains("Campaign sea") && $0.contains("already in campaign `chronicle`") }, "\(unlisted)")
    let unknown = errors(replacing: "opensAfter: the-crossing", with: "opensAfter: atlantis")
        + errors(replacing: "chapters: [two-shores]", with: "chapters: [two-shores, atlantis]")
        + errors(replacing: "title: The Merchant Sea, chapters: [two-shores]", with: "title: \"\", chapters: []")
    #expect(unknown.contains { $0.contains("`opensAfter` names unknown chapter `atlantis`") }, "\(unknown)")
    #expect(unknown.contains { $0.contains("`chapters` names unknown chapter `atlantis`") }, "\(unknown)")
    #expect(unknown.contains { $0.contains("`title` must not be empty") }, "\(unknown)")
}

@Test("malformed goals, directives, rewards and setup are rejected")
func malformedChapterFieldsAreRejected() {
    let cases: [(edit: (String, String), expected: String)] = [
        (("{ residents: 24 }", "{ residents: 24, age: medieval }"), "exactly one of"),
        (("{ residents: 24 }", "{ tier: citizens }"), "exactly one of"),
        (("{ pushMineOut: 16 }", "{ pushMineOut: 16, noMountains: home }"), "exactly one of"),
        (("{ pushMineOut: 16 }", "{ pushMineOut: 0 }"), "positive radius"),
        (("keep: 15", "keep: 150"), "percent"),
        (("{ noMountains: 2 }", "{ noMountains: 0 }"), "a rank from 1"),
        (("reward: { banner: Hearth }", "reward: { banner: Hearth, decor: Stone }"), "exactly one of"),
        (("layout: single-island", "layout: continent"), "`layout`"),
        (("seed: 101", "seed: -1"), "`seed`"),
        (("rivals: 1\n    money: 1500\n    directives", "rivals: 9\n    money: 1500\n    directives"), "`rivals`"),
        (("age: antiquity\n    money: 1000", "age: antiquity\n    rivals: 1\n    money: 1000"), "archipelago"),
        (("money: 1000", "money: -5"), "`money`"),
        (("overrides: { hard: { money: 600 } }", "overrides: { brutal: { money: -1, stock: { silk: 1 } } }"), "brutal"),
        (("{ residents: 24 }", "{ residents: 0 }"), "must be positive"),
        (("lose: { deadline: -496 }", "lose: { deadline: -600 }"), "after the start year"),
        (("rivalRace: { age: medieval }", "rivalRace: { age: medieval, residents: 5, tier: nobles }"), "exactly one of age or residents"),
        (("rivalRace: { residents: 60 }", "rivalRace: { age: stone }"), "unknown age `stone`"),
        (("collapse: 40", "collapse: -1"), "`lose.collapse`"),
        (("rivalAgeYears: { medieval: 1207 }", "rivalAgeYears: { stone: 1207 }"), "`rivalAgeYears`"),
        (("sweep: { firstSteps: true, market: true }", "sweep: { order: reckless }"), "`sweep.order`"),
        (("comingLater: true", "comingLater: true\n    difficulties: [brutal]"), "brutal"),
        (("comingLater: true", "comingLater: true\n    difficulties: []"), "`difficulties`"),
        (("ending: One town.", "ending: \"\""), "`ending` must not be empty"),
        (("title: Two Shores", "title: \"\""), "`title` must not be empty")
    ]
    for (edit, expected) in cases {
        let found = errors(replacing: edit.0, with: edit.1)
        #expect(found.contains { $0.contains(expected) }, "\(edit.1): \(found)")
    }
    let raceWithoutRivals = errors(replacing: "rivals: 1\n    money: 1500\n    goals", with: "money: 1500\n    goals")
    #expect(raceWithoutRivals.contains { $0.contains("needs rivals") }, "\(raceWithoutRivals)")
}

@Test("the emitter writes the campaign catalog")
func theEmitterWritesTheCampaignCatalog() throws {
    let data = try Fixtures.load(Fixtures.withExtraPack(chapterPack)).get()
    let source = try #require(SwiftEmitter.emit(data)["Campaign+Generated.swift"])
    let expected = [
        "Campaign(id: \"sea\", title: \"The Merchant Sea\", chapters: [\"two-shores\"], opensAfter: \"the-crossing\")",
        "start: ChapterStart(money: 1000, stock: [.planks: 5, .wood: 6])",
        "overrides: [.hard: ChapterStartOverride(money: 600, stock: nil)]",
        "GoalState(goal: .buildings(.house, 3), isBonus: false, holdsForSeason: false)",
        "GoalState(goal: .population(20, atLeast: .citizens), isBonus: true, holdsForSeason: true)",
        "directives: [.thinForest(.home, keepPercent: 15), .pushMineOut(radius: 16), .noMountains(.other(rank: 2)), .raiseMineSite(.home)]",
        "loseConditions: [.deadline(year: 1206), .rivalRace(.age(.medieval)), .collapse(below: 40)]",
        ".rivalRace(.population(60, atLeast: .peasants))",
        "rivalAgeYears: [.medieval: 1207]",
        "GoalState(goal: .landedByShip(.planks, 60)", "GoalState(goal: .outgrowRivals", "GoalState(goal: .tradeEarnings(400)",
        "reward: .mapPreset(\"The Crossing\")",
        "events: [ScheduledSeasonalEvent(year: 1202, event: .fire, onset: .summer)], randomEvents: false",
        "comingLater: true"
    ]
    for line in expected {
        #expect(source.contains(line), "\(line)")
    }
    let empty = try #require(SwiftEmitter.emit(Fixtures.load().get())["Campaign+Generated.swift"])
    #expect(empty.contains("static let campaigns: [Campaign] = []"))
    #expect(empty.contains("static let chapters: [Chapter] = []"))
}

/// The YAML parser rejects a repeated key before any reader sees it, so
/// the readers' `Dictionary(uniqueKeysWithValues:)` never meets one.
@Test("a repeated key in a chapter mapping is an error, not a crash")
func aRepeatedKeyInAChapterMappingIsAnError() {
    let overrides = errors(
        replacing: "overrides: { hard: { money: 600 } }",
        with: "overrides: { hard: { money: 600 }, hard: { money: 500 } }"
    )
    #expect(overrides.contains { $0.contains("duplicated key(s): 'hard'") }, "\(overrides)")
    let years = errors(replacing: "rivalAgeYears: { medieval: 1207 }", with: "rivalAgeYears: { medieval: 1207, medieval: 1208 }")
    #expect(years.contains { $0.contains("duplicated key(s): 'medieval'") }, "\(years)")
}

@Test("a campaign that opens after its own chapter, or in a cycle, is rejected")
func aCampaignThatCanNeverOpenIsRejected() {
    let own = errors(replacing: "opensAfter: the-crossing", with: "opensAfter: two-shores")
    #expect(own.contains { $0.contains("Campaign sea") && $0.contains("never open") }, "\(own)")
    let cycle = errors(
        replacing: "title: The Long Chronicle, chapters: [first-fires, the-crossing] }",
        with: "title: The Long Chronicle, chapters: [first-fires, the-crossing], opensAfter: two-shores }"
    )
    #expect(cycle.contains { $0.contains("Campaign chronicle") && $0.contains("never open") }, "\(cycle)")
    #expect(cycle.contains { $0.contains("Campaign sea") && $0.contains("never open") }, "\(cycle)")
}

@Test("a chapter that schedules a disabled event is rejected")
func aChapterThatSchedulesADisabledEventIsRejected() {
    let found = errors(replacing: "    effect: fire\n", with: "    effect: fire\n    enabled: false\n")
    #expect(found.contains { $0.contains("Chapter the-crossing") && $0.contains("`fire`") && $0.contains("disabled") }, "\(found)")
}
