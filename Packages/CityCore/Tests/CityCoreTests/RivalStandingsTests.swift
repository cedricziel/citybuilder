import Foundation
import Testing
@testable import CityCore

// rival-towns scenarios for standings, the outgrow goal and the
// Island Rivalry scenario (openspec/changes/add-rival-towns, M3).

private func populated(player: UInt32, rivals: [UInt32]) -> World {
    var world = World.newGame(layout: .archipelago, seed: 0, difficulty: .hard)
    world.testAddResidents(player, owner: .player)
    for (offset, residents) in rivals.enumerated() {
        world.testAddResidents(residents, owner: .rival(RivalID(offset + 1)))
    }
    return world
}

@Test("scenario: standings order")
func scenarioStandingsOrder() throws {
    let world = populated(player: 40, rivals: [52, 40, 0])
    let rows = world.standings()
    #expect(rows.map(\.owner) == [.rival(1), .player, .rival(2), .rival(3)])
    #expect(rows.map(\.population) == [52, 40, 40, 0])
    let you = try #require(rows.first { $0.owner == .player })
    #expect(you.name == "You")
    #expect(you.colourHex == "#D4A017")
    #expect(you.wealth == world.economy.balance)
    #expect(you.age == world.age)
    let first = try #require(rows.first)
    #expect(first.name == world.rival(1)?.name)
    #expect(first.colourHex == "#B03A2E")
    #expect(first.wealth == world.rival(1)?.treasury)
}

@Test("scenario: tied is not enough")
func scenarioTiedIsNotEnough() {
    var world = populated(player: 52, rivals: [52, 10, 3])
    world.goals = [GoalState(goal: .outgrowRivals)]
    let progress = world.progress(toward: .outgrowRivals)
    #expect(progress.current == 52)
    #expect(progress.target == 53)
    _ = world.testRun(ticks: 10)
    #expect(world.goals.first?.isMet == false)
}

@Test("scenario: outgrown")
func scenarioOutgrown() {
    var world = populated(player: 53, rivals: [52, 10, 3])
    world.goals = [GoalState(goal: .outgrowRivals)]
    _ = world.testRun(ticks: 10)
    #expect(world.goals.first?.isMet == true)
}

@Test("outgrow goal without rivals needs one resident")
func outgrowGoalWithoutRivalsNeedsOneResident() {
    var world = World.newGame(layout: .singleIsland, seed: 0)
    #expect(world.progress(toward: .outgrowRivals).current == 0)
    #expect(world.progress(toward: .outgrowRivals).target == 1)
    world.testAddResidents(1, owner: .player)
    #expect(world.progress(toward: .outgrowRivals).current == 1)
}

@Test("scenario: island rivalry setup")
func scenarioIslandRivalrySetup() {
    let scenario = Scenario.islandRivalry
    #expect(scenario.requiredLayout == .archipelago)
    #expect(Scenario.firstHarvest.requiredLayout == nil)
    let world = World.newGame(layout: .singleIsland, seed: 0, culture: .northernEuropean, scenario: scenario)
    #expect(world.layout == .archipelago)
    #expect(world.age == .medieval)
    #expect(world.difficulty == .normal)
    #expect(world.rivals.count == 2)
    #expect(world.goals.map(\.goal) == [.outgrowRivals, .population(80, atLeast: .peasants)])
    #expect(scenario.rawValue == "island-rivalry")
    #expect(scenario.blurb == "Out-build two rival towns and reach 80 residents.")
}
