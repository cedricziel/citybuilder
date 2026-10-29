import Foundation
import Testing
@testable import CityCore
@testable import CityUI

// Scenarios from openspec/changes/add-campaigns (platform-shells /
// Campaigns on the title screen, Goals panel shows bonus goals and
// limits). The campaigns are test placeholders, not campaign content.

func testChapter(
    _ id: String, culture: Culture? = nil, comingLater: Bool = false, difficulties: [Difficulty] = Difficulty.allCases,
    loseConditions: [LoseCondition] = [.deadline(year: 1206)], rivals: Int = 0
) -> Chapter {
    Chapter(
        id: id, title: "Chapter \(id)", intro: "Intro of \(id).", ending: "Ending of \(id).",
        layout: rivals > 0 ? .archipelago : .singleIsland, seed: 3, age: .medieval, culture: culture, rivals: rivals,
        start: ChapterStart(money: 1000, stock: [.wood: 6]),
        goals: [GoalState(goal: .population(40, atLeast: .peasants)), GoalState(goal: .treasury(1500), isBonus: true)],
        loseConditions: loseConditions, difficulties: difficulties, reward: .banner("Banner \(id)"), comingLater: comingLater
    )
}

@MainActor
func testProgress(won: [String] = [], comingLater: Set<String> = []) -> CampaignProgressModel {
    let chapters = ["c1", "c2", "c3", "s1", "g1"].map { id in
        testChapter(id, culture: id == "g1" ? .northernEuropean : nil, comingLater: comingLater.contains(id))
    }
    var progress = CampaignProgress()
    for id in won {
        if let chapter = chapters.first(where: { $0.id == id }) {
            progress.recordWin(of: chapter, difficulty: .normal, laurels: 1)
        }
    }
    return CampaignProgressModel(
        progress: progress,
        campaigns: [
            Campaign(id: "chronicle", title: "The Long Chronicle", chapters: ["c1", "c2", "c3"]),
            Campaign(id: "sea", title: "The Merchant Sea", chapters: ["s1"], opensAfter: "c3"),
            Campaign(id: "ground", title: "Hard Ground", chapters: ["g1"], opensAfter: "c3")
        ],
        chapters: chapters
    )
}

@MainActor
@Test("scenario: locked chapter names its key")
func scenarioLockedChapterNamesItsKey() {
    let model = ChapterSelectModel(progress: testProgress(won: ["c1"]))
    let rows = model.sections.flatMap(\.rows)
    let statuses = Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0.status) })
    #expect(statuses["c1"] == "Won on Normal · 1 laurel")
    #expect(statuses["c2"] == "Open")
    #expect(statuses["c3"] == "Win chapter 2")
    #expect(statuses["s1"] == "Win The Long Chronicle chapter 3")
    #expect(model.selectedID == "c2")
    #expect(model.sections.first?.tally == "1 of 3 won")
    model.select("c3")
    #expect(!model.canStart)
    #expect(model.blockedReason == "Win chapter 2")
    #expect(model.makeWorld() == nil)
}

@MainActor
@Test("scenario: fixed culture hides the culture picker")
func scenarioFixedCultureHidesTheCulturePicker() {
    let model = ChapterSelectModel(progress: testProgress(won: ["c1", "c2", "c3"]))
    model.select("g1")
    #expect(!model.showsCulturePicker)
    #expect(model.selected?.culture == .northernEuropean)
    model.select("c3")
    #expect(model.showsCulturePicker)
}

@MainActor
@Test("an empty catalog shows the campaigns are on their way")
func anEmptyCatalogShowsTheCampaignsAreOnTheirWay() {
    let model = ChapterSelectModel(progress: CampaignProgressModel(campaigns: [], chapters: []))
    #expect(model.isEmpty)
    #expect(model.selected == nil && !model.canStart)
    #expect(model.selectedEyebrow == nil && model.blockedReason == nil)
    #expect(!model.showsCulturePicker && model.difficulties == Difficulty.allCases)
}

@MainActor
@Test("choosing a chapter starts its world with the picks")
func choosingAChapterStartsItsWorld() throws {
    let progress = testProgress(comingLater: ["c2"])
    let chapters = progress.chapters.map { $0.id == "c1" ? testChapter("c1", difficulties: [.easy, .hard]) : $0 }
    let model = ChapterSelectModel(
        progress: CampaignProgressModel(campaigns: progress.campaigns, chapters: chapters), culture: .eastAsian
    )
    #expect(model.selectedID == "c1")
    #expect(model.difficulty == .easy)
    #expect(model.selectedEyebrow == "The Long Chronicle · Chapter 1")
    model.difficulty = .hard
    let world = try #require(model.makeWorld())
    #expect(world.difficulty == .hard && world.culture == .eastAsian)
    #expect(world.chapterRules.chapterID == "c1")
    let chapter = try #require(model.selected)
    #expect(model.mapImage(for: chapter) != nil)
    #expect(model.mapImage(for: chapter) === model.mapImage(for: chapter))
    model.select("c2")
    #expect(model.blockedReason == "Coming later")
}

@MainActor
@Test("a win opens the next chapter and merges with another device")
func aWinOpensTheNextChapter() throws {
    let progress = testProgress()
    let first = try #require(progress.chapter("c1"))
    let next = progress.recordWin(of: first, difficulty: .hard, laurels: 1)
    #expect(next?.id == "c2")
    #expect(progress.nextOpenChapter(after: "c3") == nil)
    #expect(progress.nextOpenChapter(after: "atlantis") == nil)
    var other = CampaignProgress()
    try other.recordWin(of: #require(progress.chapter("c2")), difficulty: .easy, laurels: 0)
    progress.merge(other)
    #expect(progress.status(of: "c3") == .open)
}

@Test("scenario: deadline readout")
func scenarioDeadlineReadout() {
    #expect(ChapterText.timeLeft(until: 1206, from: GameDate(year: 1204, season: .summer)) == "1 year, 2 seasons left")
    #expect(ChapterText.timeLeft(until: 1206, from: GameDate(year: 1205, season: .autumn)) == "1 season left")
    #expect(ChapterText.timeLeft(until: 1206, from: GameDate(year: 1203, season: .winter)) == "2 years left")
    #expect(ChapterText.timeLeft(until: 1206, from: GameDate(year: 1205, season: .winter)) == "Last season")
}

@Test("chapter texts read as the cards and the select screen show them")
func chapterTextsRead() {
    let world = World.newGame()
    #expect(ChapterText.lost(.deadline, in: world) == "The year turned before the goals were met")
    #expect(ChapterText.lost(.collapse, in: world) == "The town emptied out")
    #expect(ChapterText.lost(.bankruptcy, in: world) == "The treasury ran dry")
    #expect(ChapterText.lost(.rivalRace(9), in: world) == "A rival got there first")
    let chapter = testChapter(
        "c1",
        loseConditions: [.deadline(year: 1210), .rivalRace(.age(.renaissance)), .collapse(below: 40)],
        rivals: 1
    )
    #expect(ChapterText.start(chapter) == "Medieval, 1200, 1 rival")
    #expect(ChapterText.lostIf(chapter.loseConditions)
        == "1210 begins, or a rival reaches the Renaissance first, or the town falls below 40 residents for a season, or bankruptcy")
    #expect(ChapterText.reward(.decor("Founder's stone")) == "Decor “Founder's stone”")
    #expect(ChapterText.reward(.mapPreset("Two Shores")) == "Map preset “Two Shores”")
    #expect(ChapterText.year(-496) == "497 BC")
    #expect(ChapterText.raceTarget(.population(60, atLeast: .peasants)) == "60 residents")
}

@Test("goals read as targets")
func goalsReadAsTargets() {
    let lines: [(Goal, String)] = [
        (.population(40, atLeast: .peasants), "40 residents"),
        (.population(20, atLeast: .merchants), "20 merchants"),
        (.age(.renaissance), "Reach the Renaissance age"),
        (.stock(.bread, 20), "20 bread in store"),
        (.outgrowRivals, "Outgrow every rival"),
        (.orders(1), "Fulfil an order"),
        (.orders(6), "Fulfil 6 orders"),
        (.buildings(.windmill, 1), "Own a windmill"),
        (.buildings(.house, 3), "Own 3 houses"),
        (.signatureProjects(1), "Complete a signature project"),
        (.signatureProjects(2), "Complete 2 signature projects"),
        (.research(.metallurgy), "Research Metallurgy"),
        (.treasury(1200), "Treasury of " + HUDViewModel.formatMoney(1200, locale: .current)),
        (.netIncome(60), "Net income of $60 a season"),
        (.tradeEarnings(300), "Earn $300 from trade"),
        (.landedByShip(.ore, 30), "Land 30 ore at home by ship")
    ]
    for (goal, text) in lines {
        #expect(ChapterText.goal(goal, culture: nil) == text)
    }
    let held = GoalState(goal: .population(20, atLeast: .merchants), holdsForSeason: true)
    #expect(ChapterText.goal(held, culture: .mediterranean).hasSuffix("for a season"))
}

@MainActor
@Test("scenario: sandbox options stay open")
func scenarioSandboxOptionsStayOpen() {
    // No reward gates a sandbox option: with no chapter won, every culture,
    // age, difficulty and layout still starts a game.
    let dialog = NewGameDialogViewModel()
    for culture in Culture.allCases {
        dialog.culture = culture
        #expect(dialog.commit()?.culture == culture)
    }
    for age in Age.allCases {
        dialog.age = age
        #expect(dialog.commit()?.age == age)
    }
    for difficulty in Difficulty.allCases {
        dialog.difficulty = difficulty
        #expect(dialog.commit()?.difficulty == difficulty)
    }
    for layout in WorldLayout.allCases {
        dialog.layout = layout
        #expect(dialog.commit()?.layout == layout)
    }
}

@Test("building goals use the right plural and article")
func buildingGoalsUseTheRightPluralAndArticle() {
    let lines: [(Goal, String)] = [
        (.buildings(.bakery, 3), "Own 3 bakeries"),
        (.buildings(.gallery, 2), "Own 2 galleries"),
        (.buildings(.windmill, 2), "Own 2 windmills"),
        (.buildings(.bakery, 1), "Own a bakery"),
        (.buildings(.ruins, 2), "Own 2 ruins")
    ]
    for (goal, text) in lines {
        #expect(ChapterText.goal(goal, culture: nil) == text)
    }
    #expect(ChapterText.withArticle("observatory") == "an observatory")
    #expect(ChapterText.withArticle("mine") == "a mine")
}
