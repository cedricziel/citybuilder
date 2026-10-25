import Foundation
import Testing
@testable import CityCore

// Scenarios from openspec/changes/add-forestry:
// buildings-and-construction / Wood producers cost no materials.

private func grassWorld() -> World {
    World.fixtureWithTerrain(width: 12, height: 12, fill: .grass, seed: 1)
}

@Test("scenario: lumberjack hut spec has no material cost")
func scenarioLumberjackHutSpecHasNoMaterialCost() {
    let spec = BuildingCatalog.spec(for: .lumberjackHut)
    #expect(spec.materialCost.isEmpty)
    #expect(spec.cost == 80)
}

@Test("scenario: a town without wood can still build a lumberjack hut")
func scenarioATownWithoutWoodCanStillBuildALumberjackHut() throws {
    var world = World.newGame(layout: .singleIsland, seed: 0)
    let townCenter = try #require(world.buildings.values.first { $0.kind == .townCenter })
    world.stockpiles[townCenter.id] = World.newStockpile(for: .townCenter) ?? Stockpile(capacity: 0)
    world.economy.balance = 500
    let island = try #require(world.islandID(at: townCenter.anchor))
    let site = try #require(world.testFirstPlaceable(.lumberjackHut, onIsland: island, for: .player))
    world.enqueue(.place(.lumberjackHut, at: site))
    world.tick()
    let hut = try #require(world.occupiedTiles[site].flatMap { world.buildings[$0] })
    #expect(hut.kind == .lumberjackHut)
    #expect(hut.constructionState == .actively)
    #expect(world.economy.balance == 420)
}

@Test func savedWaitingLumberjackHutStartsOnTheNextTick() {
    var world = grassWorld()
    let id = EntityID(raw: world.nextEntityRaw)
    world.nextEntityRaw &+= 1
    world.buildings[id] = Building(
        id: id, kind: .lumberjackHut, anchor: TileCoordinate(x: 4, y: 4), state: .constructing,
        constructionState: .waitingForMaterials, materialsDelivered: [.wood: 1]
    )
    let events = world.tick().events
    #expect(world.buildings[id]?.constructionState == .actively)
    #expect(world.buildings[id]?.ticksSincePlacement == 1)
    #expect(events.contains(.constructionStarted(building: id)))
}
