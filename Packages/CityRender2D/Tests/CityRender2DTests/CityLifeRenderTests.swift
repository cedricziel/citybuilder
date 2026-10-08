import CityCore
import SpriteKit
import Testing
@testable import CityRender2D

// Scenarios from openspec/changes/add-city-life.

private func snapshot(_ base: WorldSnapshot, tick: UInt64, pops: [EntityID: HousePopulation]) -> WorldSnapshot {
    WorldSnapshot(
        tickCount: tick, simulatedTime: base.simulatedTime, mapWidth: base.mapWidth, mapHeight: base.mapHeight,
        terrainGrid: base.terrainGrid, occupiedTiles: base.occupiedTiles, buildings: base.buildings,
        carriers: base.carriers, economy: base.economy, totalPopulation: base.totalPopulation, camera: base.camera,
        housePopulations: pops
    )
}

private func houseOnRoad() throws -> (WorldSnapshot, EntityID) {
    var world = World.fixtureWithTerrain(width: 10, height: 10, fill: .grass, seed: 1)
    world.enqueue(.place(.house, at: TileCoordinate(x: 2, y: 2)))
    for x in 0 ..< 8 {
        world.enqueue(.place(.road, at: TileCoordinate(x: x, y: 4)))
    }
    for _ in 0 ..< 40 {
        world.tick()
    }
    let house = try #require(world.occupiedTiles[TileCoordinate(x: 2, y: 2)])
    return (world.snapshot(), house)
}

@Test("scenario: strollers by day")
func scenarioStrollersByDay() throws {
    let (base, house) = try houseOnRoad()
    var pop = HousePopulation()
    pop.population = 9
    let strollers = StrollerPlanner.strollers(in: snapshot(base, tick: 600, pops: [house: pop]))
    #expect(strollers.count { $0.house == house } == 3)
}

@Test("scenario: no strollers at night")
func scenarioNoStrollersAtNight() throws {
    let (base, house) = try houseOnRoad()
    var pop = HousePopulation()
    pop.population = 9
    #expect(StrollerPlanner.strollers(in: snapshot(base, tick: 1200, pops: [house: pop])).isEmpty)
}

@Test("strollers stay on road tiles near their house")
func strollersStayOnRoadsNearTheirHouse() throws {
    let (base, house) = try houseOnRoad()
    var pop = HousePopulation()
    pop.population = 6
    for tick: UInt64 in [400, 500, 650, 800] {
        for stroller in StrollerPlanner.strollers(in: snapshot(base, tick: tick, pops: [house: pop])) {
            #expect(stroller.from.y == 4 && stroller.to.y == 4)
            #expect((0 ..< 8).contains(stroller.from.x))
        }
    }
}

@MainActor
@Test("scenario: night overlay")
func scenarioNightOverlay() throws {
    let (base, _) = try houseOnRoad()
    let scene = IsoWorldScene()
    scene.size = CGSize(width: 1024, height: 768)
    scene.applyTimeOfDay(TimeOfDay(tick: snapshot(base, tick: 1200, pops: [:]).tickCount))
    #expect(abs(scene.nightOverlay.alpha - 0.55) < 0.001)
    scene.applyTimeOfDay(TimeOfDay(tick: 600))
    #expect(scene.nightOverlay.alpha == 0)
}
