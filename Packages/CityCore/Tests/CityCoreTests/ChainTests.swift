import Foundation
import Testing
@testable import CityCore

// Scenarios from openspec/changes/deepen-production-chains.

private func operational(_ kind: BuildingKind, in world: inout World, at anchor: TileCoordinate) throws -> EntityID {
    world.enqueue(.place(kind, at: anchor))
    world.tick()
    let id = try #require(world.occupiedTiles[anchor])
    while world.buildings[id]?.state != .operational {
        world.tick()
    }
    return id
}

private func run(_ world: inout World, ticks: Int) {
    for _ in 0 ..< ticks {
        world.tick()
    }
}

private func grass() -> World {
    World.fixtureWithTerrain(width: 6, height: 6, fill: .grass, seed: 1)
}

@Test("scenario: windmill grinds grain into flour")
func scenarioWindmillGrindsGrainIntoFlour() throws {
    var world = grass()
    let id = try operational(.windmill, in: &world, at: TileCoordinate(x: 1, y: 1))
    world.stockpiles[id]?.deposit(.grain, amount: 2)
    run(&world, ticks: 40)
    #expect(world.stockpiles[id]?.quantity(of: .flour) == 1)
    #expect(world.stockpiles[id]?.quantity(of: .grain) == 0)
}

@Test("scenario: bakery bakes bread from flour")
func scenarioBakeryBakesBreadFromFlour() throws {
    var world = grass()
    let id = try operational(.bakery, in: &world, at: TileCoordinate(x: 1, y: 1))
    world.stockpiles[id]?.deposit(.flour, amount: 1)
    run(&world, ticks: 50)
    #expect(world.stockpiles[id]?.quantity(of: .bread) == 1)
    #expect(world.stockpiles[id]?.quantity(of: .flour) == 0)
}

@Test("scenario: smelter needs both ore and charcoal")
func scenarioSmelterNeedsBothOreAndCharcoal() throws {
    var world = grass()
    let id = try operational(.smelter, in: &world, at: TileCoordinate(x: 1, y: 1))
    world.stockpiles[id]?.deposit(.ore, amount: 2)
    run(&world, ticks: 60)
    #expect(world.stockpiles[id]?.quantity(of: .iron) == 0)
    #expect(world.stockpiles[id]?.quantity(of: .ore) == 2)
}

@Test("scenario: toolsmith forges tools from iron and planks")
func scenarioToolsmithForgesToolsFromIronAndPlanks() throws {
    var world = grass()
    let id = try operational(.toolsmith, in: &world, at: TileCoordinate(x: 1, y: 1))
    world.stockpiles[id]?.deposit(.iron, amount: 1)
    world.stockpiles[id]?.deposit(.planks, amount: 1)
    run(&world, ticks: 60)
    #expect(world.stockpiles[id]?.quantity(of: .tools) == 1)
    #expect(world.stockpiles[id]?.quantity(of: .iron) == 0)
    #expect(world.stockpiles[id]?.quantity(of: .planks) == 0)
}

@Test("mine and charcoal burner produce their goods")
func mineAndCharcoalBurnerProduce() throws {
    var world = World.fixtureWithTerrain(width: 8, height: 6, fill: .mountain, seed: 1)
    let mine = try operational(.mine, in: &world, at: TileCoordinate(x: 1, y: 1))
    let burner = try operational(.charcoalBurner, in: &world, at: TileCoordinate(x: 4, y: 1))
    world.stockpiles[burner]?.deposit(.wood, amount: 2)
    run(&world, ticks: 50)
    #expect(world.stockpiles[mine]?.quantity(of: .ore) == 1)
    #expect(world.stockpiles[burner]?.quantity(of: .charcoal) == 1)
}

@Test("grain farm grows grain")
func grainFarmGrowsGrain() throws {
    var world = grass()
    let id = try operational(.grainFarm, in: &world, at: TileCoordinate(x: 1, y: 1))
    run(&world, ticks: 40)
    #expect(world.stockpiles[id]?.quantity(of: .grain) == 1)
}

@Test("scenario: chain building specs are catalogued")
func scenarioChainBuildingSpecsAreCatalogued() {
    let windmill = BuildingCatalog.spec(for: .windmill)
    #expect(windmill.footprint == Footprint(width: 2, height: 2))
    #expect(windmill.cost == 110)
    #expect(windmill.materialCost == [.wood: 3, .planks: 3])
    let expected: [BuildingKind: (Int64, [Good: Int])] = [
        .grainFarm: (60, [.wood: 2]),
        .mine: (120, [.wood: 4, .planks: 2]),
        .charcoalBurner: (70, [.wood: 3]),
        .smelter: (150, [.wood: 4, .planks: 4]),
        .toolsmith: (140, [.wood: 2, .planks: 4])
    ]
    for (kind, (cost, materials)) in expected {
        #expect(BuildingCatalog.spec(for: kind).cost == cost, "\(kind)")
        #expect(BuildingCatalog.spec(for: kind).materialCost == materials, "\(kind)")
    }
}

@Test("scenario: mine on grass is rejected")
func scenarioMineOnGrassIsRejected() {
    let world = grass()
    #expect(world.canPlace(.mine, at: TileCoordinate(x: 1, y: 1)) == .rejected(.needsTerrain(.mountain)))
}

@Test("scenario: mine on the mountainside is allowed")
func scenarioMineOnTheMountainsideIsAllowed() {
    var world = grass()
    world.terrainGrid[1 * 6 + 1] = .mountain
    world.terrainGrid[1 * 6 + 2] = .mountain
    #expect(world.canPlace(.mine, at: TileCoordinate(x: 1, y: 1)) == .allowed)
}
