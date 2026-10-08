import Foundation
import Testing
@testable import CityCore

// rival-towns scenarios for setup, identity, purse and player-only
// effects (openspec/changes/add-rival-towns, M1).

// MARK: - Rivals in archipelago games

@Test("scenario: hard archipelago seats three rivals")
func scenarioHardArchipelagoSeatsThreeRivals() {
    let world = World.newGame(layout: .archipelago, seed: 0, difficulty: .hard)
    #expect(world.rivals.map(\.id) == [1, 2, 3])
    #expect(world.rivals.map(\.islandID) == [5, 2, 1])
    #expect(world.owner(ofIsland: 5) == .rival(1))
    #expect(world.owner(ofIsland: 2) == .rival(2))
    #expect(world.owner(ofIsland: 1) == .rival(3))
    #expect(world.owner(ofIsland: 3) == .player)
    #expect(world.owner(ofIsland: 4) == .player)
}

@Test("scenario: easy archipelago seats one rival")
func scenarioEasyArchipelagoSeatsOneRival() {
    let world = World.newGame(layout: .archipelago, seed: 0, difficulty: .easy)
    #expect(world.rivals.map(\.islandID) == [5])
}

@Test("scenario: single island has no rivals")
func scenarioSingleIslandHasNoRivals() {
    let world = World.newGame(layout: .singleIsland, seed: 0, difficulty: .hard)
    #expect(world.rivals.isEmpty)
}

@Test("scenario: rivals turned off")
func scenarioRivalsTurnedOff() {
    let world = World.newGame(layout: .archipelago, seed: 0, difficulty: .normal, rivals: false)
    #expect(world.rivals.isEmpty)
    #expect(world.islands.allSatisfy { world.owner(ofIsland: $0.id) == .player })
    #expect(world.buildings.values.allSatisfy { $0.owner == .player })
}

// MARK: - Rival identity

@Test("scenario: rival cultures differ from the player's")
func scenarioRivalCulturesDifferFromThePlayers() {
    let world = World.newGame(layout: .archipelago, seed: 0, culture: .northernEuropean, difficulty: .hard)
    #expect(world.rivals.map(\.culture) == [.mediterranean, .eastAsian, .middleEastern])
    let eastern = World.newGame(layout: .archipelago, seed: 0, culture: .eastAsian, difficulty: .hard)
    #expect(eastern.rivals.map(\.culture) == [.northernEuropean, .mediterranean, .middleEastern])
}

@Test("scenario: rival starting state")
func scenarioRivalStartingState() throws {
    let world = World.newGame(layout: .archipelago, seed: 0, age: .medieval, difficulty: .hard)
    let rival = try #require(world.rival(1))
    let island = try #require(world.islands.first { $0.id == 5 })
    #expect(rival.name == island.name)
    #expect(rival.colour == .crimson)
    #expect(rival.colour.hex == "#B03A2E")
    #expect(world.rival(2)?.colour == .azure)
    #expect(world.rival(3)?.colour == .emerald)
    #expect(rival.treasury == 1400)
    #expect(rival.age == .medieval)
    let townCenter = try #require(world.testTownCenter(onIsland: 5))
    #expect(rival.townCenterID == townCenter.id)
    #expect(townCenter.owner == .rival(1))
    let stock = try #require(world.stockpiles[townCenter.id])
    #expect(stock.quantity(of: .wood) == 4)
    #expect(stock.quantity(of: .planks) == 3)
    #expect(stock.quantity(of: .food) == 1)
    #expect(world.testTownCenter(onIsland: 3)?.owner == .player)
}

// MARK: - Rival purse

@Test("scenario: rival tax goes to the rival")
func scenarioRivalTaxGoesToTheRival() throws {
    var world = World.newGame(layout: .archipelago, seed: 0, difficulty: .normal)
    _ = world.testRun(ticks: 49)
    world.testAddResidents(10, owner: .rival(1))
    let balance = world.economy.balance
    let treasury = try #require(world.rival(1)).treasury
    world.tick()
    #expect(world.rival(1)?.treasury == treasury + 10)
    #expect(world.economy.balance == balance)
}

@Test("scenario: rival in debt")
func scenarioRivalInDebt() throws {
    var world = World.newGame(layout: .archipelago, seed: 0, difficulty: .normal)
    let index = try #require(world.rivals.firstIndex { $0.id == 1 })
    world.rivals[index].treasury = -20
    let before = world.buildings.values.count { $0.owner == .rival(1) }
    _ = world.testRun(ticks: 500)
    #expect(!world.economy.gameOver)
    #expect(world.rival(1)?.treasury == -20)
    #expect(world.buildings.values.count { $0.owner == .rival(1) } == before)
}

// MARK: - Rivals don't share the player's effects

@Test("scenario: rats spare the rivals")
func scenarioRatsSpareTheRivals() throws {
    var world = World.newGame(layout: .archipelago, seed: 0, difficulty: .normal)
    let rival = try #require(world.rival(1))
    world.stockpiles[rival.townCenterID]?.deposit(.food, amount: 10 - 2)
    #expect(world.stockpiles[rival.townCenterID]?.quantity(of: .food) == 10)
    world.applyHistoryEvent(.ratsInTheGranary)
    #expect(world.stockpiles[rival.townCenterID]?.quantity(of: .food) == 10)
}

@Test("scenario: stock goal ignores rival stores")
func scenarioStockGoalIgnoresRivalStores() throws {
    var world = World.newGame(layout: .archipelago, seed: 0, culture: .northernEuropean, scenario: .firstHarvest)
    let rival = try #require(world.rival(1))
    world.stockpiles[rival.townCenterID]?.deposit(.bread, amount: 25)
    let progress = world.progress(toward: .stock(.bread, 20))
    #expect(progress.current == 0)
    #expect(progress.target == 20)
}

@Test("new game with rivals leaves the rng alone")
func newGameWithRivalsLeavesTheRngAlone() {
    let solo = World.newGame(layout: .archipelago, seed: 9, difficulty: .hard, rivals: false)
    let rivals = World.newGame(layout: .archipelago, seed: 9, difficulty: .hard)
    #expect(solo.rng == rivals.rng)
}
