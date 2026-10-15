import Foundation
import Testing
@testable import CityCore

// rival-towns scenarios from openspec/changes/rival-viability-margin.

/// A Normal rival past its opening with `houses` houses, a sawmill and
/// money to spare; its script points at a house.
private func townPastOpening(houses: Int, stock: [Good: Int]) -> World {
    var world = World.newGame(layout: .archipelago, seed: 0, difficulty: .normal)
    world.setRival(1) {
        $0.ai.scriptIndex = 12
        $0.treasury = 5000
    }
    world.setRivalStock(1, stock)
    for _ in 0 ..< houses {
        world.testAddHouse(owner: .rival(1), residents: 4)
    }
    world.testAddBuilding(.sawmill, owner: .rival(1))
    return world
}

@Test("scenario: three farms for every two houses")
func scenarioThreeFarmsForEveryTwoHouses() {
    var world = townPastOpening(houses: 4, stock: [.wood: 20, .planks: 10, .food: 2])
    for _ in 0 ..< 5 {
        world.testAddBuilding(.farm, owner: .rival(1))
    }
    var fed = world
    #expect(placedKind(world.takeTurn(1).last) == .farm)
    fed.testAddBuilding(.farm, owner: .rival(1))
    #expect(placedKind(fed.takeTurn(1).last) != .farm)
}

@Test("scenario: replanting towns keep their huts")
func scenarioReplantingTownsKeepTheirHuts() {
    // Four huts with their forest cut: none counts as a hut, so wood
    // below 4 asks for a new one. Four houses allow 2 + 4 / 2 = 4 huts.
    var world = townPastOpening(houses: 4, stock: [.wood: 2, .planks: 10, .food: 10])
    for _ in 0 ..< 4 {
        world.testAddBuilding(.lumberjackHut, owner: .rival(1))
    }
    for _ in 0 ..< 4 {
        world.testAddBuilding(.farm, owner: .rival(1))
    }
    var unplanted = world
    world.testAddBuilding(.forester, owner: .rival(1))
    #expect(placedKind(world.takeTurn(1).last) != .lumberjackHut)
    #expect(placedKind(unplanted.takeTurn(1).last) == .lumberjackHut)
}

/// A town center with 2 units of room: planks, a little wood, and
/// enough food that the rival doesn't sell to clear it.
private let fullCenter: [Good: Int] = [.wood: 2, .planks: 30, .food: 6]

@Test("scenario: a full town center gets a warehouse")
func scenarioAFullTownCenterGetsAWarehouse() {
    var world = townPastOpening(houses: 4, stock: fullCenter)
    for _ in 0 ..< 6 {
        world.testAddBuilding(.farm, owner: .rival(1))
    }
    var roomy = world
    #expect(placedKind(world.takeTurn(1).last) == .warehouse)
    roomy.setRivalStock(1, [.wood: 2, .planks: 20, .food: 6])
    #expect(placedKind(roomy.takeTurn(1).last) != .warehouse)
}

@Test("scenario: the building cap does not stop a first warehouse")
func scenarioTheBuildingCapDoesNotStopAFirstWarehouse() {
    var world = townPastOpening(houses: 4, stock: fullCenter)
    // With the town center and the sawmill: Normal's cap of 48.
    for _ in 0 ..< 42 {
        world.testAddBuilding(.farm, owner: .rival(1))
    }
    var stocked = world
    #expect(placedKind(world.takeTurn(1).last) == .warehouse)
    stocked.testAddBuilding(.warehouse, owner: .rival(1))
    #expect(stocked.takeTurn(1).isEmpty)
}
