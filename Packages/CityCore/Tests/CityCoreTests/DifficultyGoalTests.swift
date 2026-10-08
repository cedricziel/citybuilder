import Testing
@testable import CityCore

// Scenarios from openspec/changes/add-difficulty-and-goals.

@Test("scenario: easy start")
func scenarioEasyStart() throws {
    let world = World.newGame(layout: .singleIsland, seed: 0, difficulty: .easy)
    #expect(world.economy.balance == 1500)
    let center = try #require(world.goodsBuffers().first)
    #expect(world.stockpiles[center.id]?.quantity(of: .wood) == 10)
    #expect(world.stockpiles[center.id]?.quantity(of: .planks) == 8)
    #expect(world.stockpiles[center.id]?.quantity(of: .food) == 4)
}

@Test("scenario: hard upkeep")
func scenarioHardUpkeep() {
    #expect(Difficulty.hard.scaledUpkeep(4) == 5)
    #expect(Difficulty.easy.scaledUpkeep(4) == 3)
    #expect(Difficulty.normal.scaledUpkeep(4) == 4)
    #expect(Difficulty.easy.scaledUpkeep(1) == 1)
    #expect(Difficulty.easy.scaledUpkeep(0) == 0)
}

@Test("scenario: easy has no rats")
func scenarioEasyHasNoRats() {
    var world = World.newGame(layout: .singleIsland, seed: 7, difficulty: .easy)
    world.difficulty = .easy
    let events = (1201 ... 1400).compactMap { world.historyEvent(forYear: $0) }
    #expect(!events.isEmpty)
    #expect(!events.contains(.ratsInTheGranary))
}

@Test("scenario: population goal")
func scenarioPopulationGoal() {
    var world = World.newGame(layout: .singleIsland, seed: 0, culture: .northernEuropean, scenario: .firstHarvest)
    var pop = HousePopulation()
    pop.population = 40
    world.populations[EntityID(raw: 9999)] = pop
    for _ in 0 ..< 10 {
        world.tick()
    }
    #expect(world.goals.first { $0.goal == .population(40, atLeast: .peasants) }?.isMet == true)
}

@Test("scenario: winning")
func scenarioWinning() {
    var world = World.newGame(layout: .singleIsland, seed: 0, culture: .northernEuropean, scenario: .steamAndSmoke)
    world.age = .industrial
    var won = 0
    for _ in 0 ..< 30 {
        won += world.tick().events.count { $0 == .scenarioWon }
    }
    #expect(world.scenarioWon)
    #expect(won == 1)
}

@Test("sandbox has no goals and never wins")
func sandboxHasNoGoalsAndNeverWins() {
    var world = World.newGame()
    for _ in 0 ..< 20 {
        world.tick()
    }
    #expect(world.goals.isEmpty)
    #expect(!world.scenarioWon)
}

@Test("scenario: first harvest setup")
func scenarioFirstHarvestSetup() {
    let world = World.newGame(layout: .singleIsland, seed: 0, culture: .mediterranean, scenario: .firstHarvest)
    #expect(world.age == .antiquity)
    #expect(world.difficulty == .easy)
    #expect(world.culture == .mediterranean)
    #expect(world.goals.map(\.goal) == [.population(40, atLeast: .peasants), .stock(.bread, 20)])
}
