import Foundation
import Testing
@testable import CityCore

// Scenarios from openspec/changes/fix-early-game-edge-cases (economy).

private func richWorld() -> World {
    var world = World.fixtureWithTerrain(width: 8, height: 8, fill: .grass, seed: 1)
    world.economy.balance = 10000
    return world
}

private func lostWorld() -> World {
    var world = richWorld()
    world.economy.gameOver = true
    return world
}

@Test("scenario: placement after game over is dropped")
func scenarioPlacementAfterGameOverIsDropped() {
    var world = lostWorld()
    world.enqueue(.place(.farm, at: TileCoordinate(x: 2, y: 2)))
    let events = world.tick().events
    #expect(world.buildings.isEmpty)
    #expect(world.economy.balance == 10000)
    #expect(!events.contains { if case .buildingPlaced = $0 { true } else { false } })
    #expect(!events.contains { if case .placementRejected = $0 { true } else { false } })
}

@Test("scenario: demolish after game over is dropped")
func scenarioDemolishAfterGameOverIsDropped() throws {
    var world = richWorld()
    world.enqueue(.place(.farm, at: TileCoordinate(x: 2, y: 2)))
    world.tick()
    let farm = try #require(world.occupiedTiles[TileCoordinate(x: 2, y: 2)])
    world.economy.gameOver = true
    world.enqueue(.demolish(at: TileCoordinate(x: 2, y: 2)))
    let events = world.tick().events
    #expect(world.buildings[farm] != nil)
    #expect(!events.contains { if case .buildingDemolished = $0 { true } else { false } })
}

@Test("scenario: lost game still saves")
func scenarioLostGameStillSaves() throws {
    var world = lostWorld()
    world.tick()
    let decoded = try JSONDecoder().decode(World.self, from: JSONEncoder().encode(world))
    #expect(decoded.economy.gameOver)
    #expect(decoded == world)
}

@Test("rival placements still apply after game over")
func rivalPlacementsStillApplyAfterGameOver() throws {
    var world = World.newGame(layout: .archipelago, seed: 0, difficulty: .normal)
    _ = world.testRun(ticks: 50)
    let hutAnchor = try #require(world.pendingCommands.last.flatMap {
        if case let .rivalPlace(_, _, anchor) = $0 { anchor } else { nil }
    })
    world.economy.gameOver = true
    world.tick()
    let hut = try #require(world.occupiedTiles[hutAnchor].flatMap { world.buildings[$0] })
    #expect(hut.owner == .rival(1))
}
