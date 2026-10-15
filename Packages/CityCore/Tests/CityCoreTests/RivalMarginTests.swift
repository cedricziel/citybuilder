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

@Test("a full town center's warehouse waits while a site waits for materials")
func warehouseWaitsForWaitingSites() {
    var world = townPastOpening(houses: 4, stock: fullCenter)
    for _ in 0 ..< 6 {
        world.testAddBuilding(.farm, owner: .rival(1))
    }
    let site = world.testAddBuilding(.house, owner: .rival(1))
    world.buildings[site]?.state = .constructing
    world.buildings[site]?.constructionState = .waitingForMaterials
    #expect(!world.takeTurn(1).contains { placedKind($0) == .warehouse })
}

/// The script step that places a growth-loop lumberjack hut.
private let hutStep = RivalAI.opening.count + 5

/// A town with 8 houses on its script's hut step: 2 + 8 / 2 = 6 huts
/// once a forester stands. Six foresters keep the forester rule quiet,
/// the huts' forest is cut, so none of them counts toward the sawmill
/// rule, and a port keeps the port rule (add-rival-trade) quiet.
private func townOnAHutStep(huts: Int) -> World {
    var world = townPastOpening(houses: 8, stock: [.wood: 10, .planks: 10, .food: 10])
    world.setRival(1) { $0.ai.scriptIndex = hutStep }
    for _ in 0 ..< 6 {
        world.testAddBuilding(.forester, owner: .rival(1))
    }
    for _ in 0 ..< 12 {
        world.testAddBuilding(.farm, owner: .rival(1))
    }
    for _ in 0 ..< huts {
        world.testAddBuilding(.lumberjackHut, owner: .rival(1))
    }
    world.testAddBuilding(.port, owner: .rival(1))
    return world
}

@Test("scenario: script hut steps stop at the hut limit")
func scenarioScriptHutStepsStopAtTheHutLimit() {
    #expect(RivalAI.scriptKind(at: hutStep) == .lumberjackHut)
    var world = townOnAHutStep(huts: 6)
    #expect(placedKind(world.takeTurn(1).last) == .house)
    #expect(world.rival(1)?.ai.scriptIndex == hutStep + 2)
    var belowLimit = townOnAHutStep(huts: 5)
    #expect(placedKind(belowLimit.takeTurn(1).last) == .lumberjackHut)
}

@Test("a skipped script step starts the next one's wait count afresh")
func skippedStepResetsTheWaitCount() {
    var world = townOnAHutStep(huts: 6)
    world.setRival(1) {
        $0.treasury = 40
        $0.ai.waitTurns = 5
    }
    #expect(world.takeTurn(1).isEmpty)
    #expect(world.rival(1)?.ai.scriptIndex == hutStep + 1)
    #expect(world.rival(1)?.ai.waitTurns == 1)
}

@Test("scenario: one warehouse per town")
func scenarioOneWarehousePerTown() {
    let warehouseStep = RivalAI.opening.count - 1
    #expect(RivalAI.scriptKind(at: warehouseStep) == .warehouse)
    var world = townPastOpening(houses: 4, stock: [.wood: 10, .planks: 10, .food: 10])
    world.setRival(1) { $0.ai.scriptIndex = warehouseStep }
    for _ in 0 ..< 6 {
        world.testAddBuilding(.farm, owner: .rival(1))
    }
    world.testAddBuilding(.lumberjackHut, owner: .rival(1))
    var constructing = world
    world.testAddBuilding(.warehouse, owner: .rival(1))
    #expect(placedKind(world.takeTurn(1).last) == .house)
    #expect(world.rival(1)?.ai.scriptIndex == warehouseStep + 2)
    let site = constructing.testAddBuilding(.warehouse, owner: .rival(1))
    constructing.buildings[site]?.state = .constructing
    #expect(placedKind(constructing.takeTurn(1).last) == .house)
}
