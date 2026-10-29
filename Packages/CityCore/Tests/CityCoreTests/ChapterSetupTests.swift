import Foundation
import Testing
@testable import CityCore

// Scenarios from openspec/changes/add-campaigns (campaigns / Chapter setup,
// Chapter build lists, Campaign rewards) and add-event-counterplay
// (seasonal-events / Chapters schedule events). The chapters here are test
// placeholders, not campaign content.

private func homeStock(_ world: World) -> [Good: Int] {
    let map = world.tileToIslandMap()
    guard let home = world.homeIslandID(in: map), let center = world.townCenter(onIsland: home, tileToIsland: map),
          let pile = world.stockpiles[center.id]
    else { return [:] }
    return Dictionary(uniqueKeysWithValues: Good.allCases.compactMap { good in
        let amount = pile.quantity(of: good)
        return amount > 0 ? (good, amount) : nil
    })
}

@Test("scenario: chronicle chapter 1 setup")
func scenarioChronicleChapterOneSetup() {
    let chapter = Chapter.testChapter(
        age: .antiquity, start: ChapterStart(money: 1000, stock: [.wood: 6, .planks: 5, .food: 2]),
        goals: [GoalState(goal: .buildings(.house, 3)), GoalState(goal: .treasury(1200), isBonus: true)],
        loseConditions: [.deadline(year: -496)]
    )
    let world = World.newGame(chapter: chapter, difficulty: .normal, culture: .mediterranean)
    let stock = homeStock(world)
    #expect(world.layout == .singleIsland && world.age == .antiquity && world.culture == .mediterranean)
    #expect(world.rivals.isEmpty && world.difficulty == .normal)
    #expect(world.economy.balance == 1000)
    #expect(stock == [.wood: 6, .planks: 5, .food: 2])
    #expect(world.goals == chapter.goals)
    #expect(world.loseConditions == [LoseConditionState(condition: .deadline(year: -496))])
    #expect(world.chapterRules.chapterID == "test-chapter")
}

@Test("scenario: rival count overrides the difficulty")
func scenarioRivalCountOverridesTheDifficulty() {
    let chapter = Chapter.testChapter(layout: .archipelago, rivals: 1)
    let world = World.newGame(chapter: chapter, difficulty: .hard, culture: .northernEuropean)
    #expect(world.rivals.count == 1)
    let sandbox = World.newGame(layout: .archipelago, seed: chapter.seed, difficulty: .hard)
    #expect(world.rivals.first?.islandID == sandbox.rivals.first?.islandID)
}

@Test("scenario: a rival waits for its year")
func scenarioARivalWaitsForItsYear() throws {
    let chapter = Chapter.testChapter(layout: .archipelago, rivals: 1, rivalAgeYears: [.renaissance: 1207])
    var world = World.newGame(chapter: chapter, difficulty: .normal, culture: .northernEuropean)
    let rival = try #require(world.rivals.first)
    var events: [WorldEvent] = []
    world.testAddResidents(64, owner: rival.owner)
    world.calendar.startYear = 1204
    world.runRivalTurn(rival.id, events: &events)
    let waiting = world.rival(rival.id)?.age
    #expect(waiting == .medieval)
    world.calendar.startYear = 1207
    world.runRivalTurn(rival.id, events: &events)
    let entered = world.rival(rival.id)?.age
    #expect(entered == .renaissance)
}

@Test("scenario: fixed culture ignores the player's pick")
func scenarioFixedCultureIgnoresThePlayersPick() {
    let chapter = Chapter.testChapter(culture: .northernEuropean)
    let world = World.newGame(chapter: chapter, difficulty: .normal, culture: .eastAsian)
    #expect(world.culture == .northernEuropean)
}

@Test("scenario: easy deadlines come later")
func scenarioEasyDeadlinesComeLater() {
    let chapter = Chapter.testChapter(loseConditions: [.deadline(year: 1206), .collapse(below: 30)])
    let easy = World.newGame(chapter: chapter, difficulty: .easy, culture: .northernEuropean)
    let normal = World.newGame(chapter: chapter, difficulty: .normal, culture: .northernEuropean)
    #expect(easy.loseConditions.map(\.condition) == [.deadline(year: 1208), .collapse(below: 30)])
    #expect(normal.loseConditions.map(\.condition) == [.deadline(year: 1206), .collapse(below: 30)])
    let odd = Chapter.testChapter(loseConditions: [.deadline(year: 1204)])
    #expect(odd.loseConditions(for: .easy) == [.deadline(year: 1206)])
}

@Test("scenario: chapter starts are reproducible")
func scenarioChapterStartsAreReproducible() {
    let chapter = Chapter.testChapter(layout: .archipelago, rivals: 2, directives: [.thinForest(.home, keepPercent: 30)])
    let first = World.newGame(chapter: chapter, difficulty: .normal, culture: .mediterranean)
    let second = World.newGame(chapter: chapter, difficulty: .normal, culture: .mediterranean)
    #expect(first == second)
}

@Test("money and stock scale with difficulty (design D3)")
func moneyAndStockScaleWithDifficulty() {
    let chapter = Chapter.testChapter(
        start: ChapterStart(money: 1200, stock: [.wood: 7, .planks: 5, .food: 1]),
        overrides: [.hard: ChapterStartOverride(stock: [.wood: 9])]
    )
    let easy = chapter.start(for: .easy), normal = chapter.start(for: .normal), hard = chapter.start(for: .hard)
    #expect(easy == ChapterStart(money: 1800, stock: [.wood: 11, .planks: 8, .food: 2]))
    #expect(normal == chapter.start)
    #expect(hard == ChapterStart(money: 850, stock: [.wood: 9]))
    #expect(ChapterStart(money: 1000, stock: [:]).scaled(for: .hard).money == 700)
    let easyOverride = Chapter.testChapter(overrides: [.easy: ChapterStartOverride(money: 2500)]).start(for: .easy)
    #expect(easyOverride.money == 2500 && easyOverride.stock == [.wood: 9, .planks: 8, .food: 3])
}

@Test("pre-researched techs are complete")
func preResearchedTechsAreComplete() {
    let chapter = Chapter.testChapter(researched: [.metallurgy])
    let world = World.newGame(chapter: chapter, difficulty: .normal, culture: .northernEuropean)
    #expect(world.research.isResearched(.metallurgy))
}

@Test("scenario: a closed building cannot be placed")
func scenarioAClosedBuildingCannotBePlaced() {
    var world = World.fixtureWithTerrain(width: 8, height: 8, fill: .grass, seed: 1)
    world.chapterRules = ChapterRules(chapterID: "test", closedBuildings: [.farm])
    #expect(world.canPlace(.farm, at: TileCoordinate(x: 2, y: 2)) == .rejected(.closed))
    #expect(PlacementRejection.closed.code == "closed")
    #expect(world.canPlace(.house, at: TileCoordinate(x: 2, y: 2)) == .allowed)
}

@Test("scenario: a closed tech is not offered")
func scenarioAClosedTechIsNotOffered() {
    var world = World.newGame(chapter: Chapter.testChapter(closedTechs: [.seafaring]), difficulty: .normal, culture: .northernEuropean)
    world.research = ResearchState(researched: [.scholarship])
    #expect(!world.canChooseResearch(.seafaring))
    world.chapterRules = ChapterRules()
    #expect(world.canChooseResearch(.seafaring) == world.research.canChoose(.seafaring))
}

@Test("scenario: a scheduled fire")
func scenarioAScheduledFire() {
    let scheduled = ScheduledSeasonalEvent(year: 1202, event: .fire, onset: .summer)
    let chapter = Chapter.testChapter(events: [scheduled], randomEvents: false)
    let world = World.newGame(chapter: chapter, difficulty: .normal, culture: .northernEuropean)
    #expect(world.seasonalEvents.schedule == [scheduled])
    #expect(!world.seasonalEvents.randomEvents)
    #expect(world.seasonalEvents.enabled)
}

@Test("scenario: a map preset reaches the sandbox")
func scenarioAMapPresetReachesTheSandbox() {
    let chapter = Chapter.testChapter(
        layout: .archipelago, seed: 301, rivals: 1, directives: [.thinForest(.home, keepPercent: 15)],
        loseConditions: [.deadline(year: 1206)]
    )
    let preset = World.newGame(mapPreset: chapter, difficulty: .hard, culture: .mediterranean, rivals: true)
    let thinned = World.newGame(layout: .archipelago, seed: 301, directives: chapter.directives)
    #expect(preset.layout == .archipelago && preset.seed == 301)
    #expect(preset.terrainGrid == thinned.terrainGrid)
    #expect(preset.goals.isEmpty && preset.loseConditions.isEmpty)
    #expect(preset.difficulty == .hard && preset.culture == .mediterranean)
    #expect(preset.rivals.count == Difficulty.hard.rivalCount)
}

@Test("chapter rules survive a save and old saves have none")
func chapterRulesSurviveASave() throws {
    let chapter = Chapter.testChapter(closedBuildings: [.port], closedTechs: [.seafaring], rivalAgeYears: [.renaissance: 1207])
    let world = World.newGame(chapter: chapter, difficulty: .normal, culture: .northernEuropean)
    let data = try JSONEncoder().encode(world)
    let loaded = try JSONDecoder().decode(World.self, from: data)
    #expect(loaded == world)
    var json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    json.removeValue(forKey: "chapterRules")
    let old = try JSONDecoder().decode(World.self, from: JSONSerialization.data(withJSONObject: json))
    #expect(old.chapterRules == ChapterRules())
}
