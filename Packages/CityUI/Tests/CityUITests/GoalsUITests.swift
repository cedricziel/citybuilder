import Testing
@testable import CityCore
@testable import CityUI

// Scenarios from openspec/changes/add-difficulty-and-goals.

@MainActor
@Test("scenario: scenario reaches the world")
func scenarioScenarioReachesTheWorld() {
    let dialog = NewGameDialogViewModel()
    dialog.mode = .scenario
    dialog.scenario = .guildTown
    let world = dialog.commit()
    #expect(world?.goals.map(\.goal) == Scenario.guildTown.goals)
    #expect(world?.difficulty == .normal)
}

@MainActor
@Test("scenario: sandbox difficulty reaches the world")
func scenarioSandboxDifficultyReachesTheWorld() {
    let dialog = NewGameDialogViewModel()
    #expect(dialog.difficulty == .normal)
    dialog.difficulty = .hard
    let world = dialog.commit()
    #expect(world?.difficulty == .hard)
    #expect(world?.goals.isEmpty == true)
    dialog.cancel()
    #expect(dialog.difficulty == .normal)
    #expect(dialog.mode == .sandbox)
}

@Test("scenario: goal progress text")
func scenarioGoalProgressText() {
    var world = World.newGame(layout: .singleIsland, seed: 0, culture: .northernEuropean, scenario: .firstHarvest)
    var pop = HousePopulation()
    pop.population = 24
    world.populations[EntityID(raw: 9999)] = pop
    let rows = GoalsPanelModel(world: world).rows
    #expect(rows.first?.text == "Residents 24/40")
    #expect(rows.last?.text.hasPrefix("Bread ") == true)
    let steam = World.newGame(layout: .singleIsland, seed: 0, culture: .northernEuropean, scenario: .steamAndSmoke)
    #expect(GoalsPanelModel(world: steam).rows.first?.text == "Reach the Industrial age")
}

@Test("outgrow goal row reads player against the largest rival")
func outgrowGoalRowText() {
    let world = World.newGame(layout: .archipelago, seed: 0, culture: .northernEuropean, scenario: .islandRivalry)
    let rows = GoalsPanelModel(world: world).rows
    #expect(rows.first?.text == "Outgrow every rival 0/1")
    #expect(rows.last?.text == "Residents 0/80")
}

@Test("campaign goal rows read their progress")
func campaignGoalRowText() {
    let world = World.newGame(layout: .singleIsland, seed: 0, culture: .northernEuropean, scenario: .firstHarvest)
    let texts = [
        Goal.buildings(.windmill, 2), .signatureProjects(1), .research(.metallurgy), .treasury(1200),
        .netIncome(100), .tradeEarnings(300), .landedByShip(.ore, 30), .orders(2)
    ].map { GoalsPanelModel.text(for: $0, in: world) }
    let expected = [
        "Windmill 0/2", "Signature projects 0/1", "Research Metallurgy", "Treasury $1500/$1200",
        "Net income last season $0/$100", "Trade earnings $0/$300", "Ore landed at home 0/30", "Fulfil orders 0/2"
    ]
    #expect(texts == expected)
}

@MainActor
@Test("scenario: win sheet appears")
func scenarioWinSheetAppears() {
    let session = GameSession(world: World.newGame())
    #expect(!session.isWinSheetPresented)
    session.noteBannerEvents(in: [.scenarioWon])
    #expect(session.isWinSheetPresented)
    #expect(session.banner?.title == "Scenario complete")
}
