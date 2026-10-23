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
    let strollers = StrollerPlanner.strollers(in: snapshot(base, tick: 180, pops: [house: pop]))
    #expect(strollers.count { $0.house == house } == 3)
}

@Test("scenario: no strollers at night")
func scenarioNoStrollersAtNight() throws {
    let (base, house) = try houseOnRoad()
    var pop = HousePopulation()
    pop.population = 9
    #expect(StrollerPlanner.strollers(in: snapshot(base, tick: 780, pops: [house: pop])).isEmpty)
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
    scene.applyTimeOfDay(TimeOfDay(tick: snapshot(base, tick: 780, pops: [:]).tickCount))
    #expect(abs(scene.nightOverlay.alpha - 0.4) < 0.001)
    scene.applyTimeOfDay(TimeOfDay(tick: 180))
    #expect(scene.nightOverlay.alpha == 0)
}

@MainActor
@Test("scenario: A stroller heading down-left faces south-west, anchored at its feet")
func strollerNodesStandOnTheirFeetUnmirrored() throws {
    let (base, house) = try houseOnRoad()
    var pop = HousePopulation()
    pop.population = 9
    let scene = IsoWorldScene()
    scene.reconcileStrollers(with: snapshot(base, tick: 180, pops: [house: pop]), now: 0)
    let planned = StrollerPlanner.strollers(in: snapshot(base, tick: 180, pops: [house: pop]))
    #expect(!planned.isEmpty && scene.strollerNodes.count == planned.count)
    for stroller in planned {
        #expect(scene.strollerNodes[StrollerKey(house: stroller.house, slot: stroller.slot)]?.facing == stroller.facing)
    }
    for stroller in planned {
        // Feet on the line between the two road tiles' centres, as far along as the stroller has come.
        let node = try #require(scene.strollerNodes[StrollerKey(house: stroller.house, slot: stroller.slot)]?.node)
        let tile = IsoMath.tileCoordinate(forScreenPoint: node.position)
        let col = Double(stroller.from.x) + 0.5 + Double(stroller.to.x - stroller.from.x) * stroller.progress
        let row = Double(stroller.from.y) + 0.5 + Double(stroller.to.y - stroller.from.y) * stroller.progress
        #expect(abs(tile.col - col) < 0.001 && abs(tile.row - row) < 0.001)
    }
    for shown in scene.strollerNodes.values {
        #expect(abs(shown.node.anchorPoint.x - SpriteAtlas.walkerAnchor.x) < 0.0001)
        #expect(abs(shown.node.anchorPoint.y - SpriteAtlas.walkerAnchor.y) < 0.0001)
        #expect(shown.node.xScale > 0)
    }
}

@MainActor
@Test("scenario: A paused carrier stands on frame 0, and walks again on the next tick")
func carriersAndStrollersStandWhilePaused() throws {
    let (base, house) = try houseOnRoad()
    var pop = HousePopulation()
    pop.population = 9
    let carrier = Carrier(
        id: EntityID(raw: 77),
        path: [TileCoordinate(x: 1, y: 4), TileCoordinate(x: 2, y: 4), TileCoordinate(x: 3, y: 4)],
        mission: .deliver(good: .grain, amount: 1, fromProducer: EntityID(raw: 1), toWarehouse: EntityID(raw: 2))
    )
    func frame(tick: UInt64) -> WorldSnapshot {
        let town = snapshot(base, tick: tick, pops: [house: pop])
        return WorldSnapshot(
            tickCount: tick, simulatedTime: town.simulatedTime, mapWidth: town.mapWidth, mapHeight: town.mapHeight,
            terrainGrid: town.terrainGrid, occupiedTiles: town.occupiedTiles, buildings: town.buildings,
            carriers: [carrier], economy: town.economy, totalPopulation: town.totalPopulation, camera: town.camera,
            housePopulations: town.housePopulations
        )
    }
    let scene = IsoWorldScene()
    func step(tick: UInt64, at now: TimeInterval) {
        let shown = frame(tick: tick)
        scene.noteTick(shown.tickCount, now: now)
        scene.reconcileCarriers(with: shown, now: now)
        scene.reconcileStrollers(with: shown, now: now)
    }
    func walking() -> [Bool] {
        [scene.carrierVisuals[carrier.id]?.walking ?? false] + scene.strollerNodes.values.map(\.walking)
    }
    step(tick: 180, at: 0)
    let started = walking()
    step(tick: 180, at: 0.5)
    let paused = walking()
    step(tick: 181, at: 0.6)
    let resumed = walking()
    #expect(started.count > 1 && !started.contains(false))
    #expect(!paused.contains(true))
    #expect(!resumed.contains(false))
}

@MainActor
@Test("strollers on the road in front of their house draw over it and over the road")
func strollersDrawOverTheHouseBehindThem() throws {
    let (base, house) = try houseOnRoad()
    var pop = HousePopulation()
    pop.population = 9
    let scene = IsoWorldScene()
    scene.size = CGSize(width: 1024, height: 768)
    scene.hasSprite = { _ in true }
    let shown = snapshot(base, tick: 180, pops: [house: pop])
    scene.dataSource = FixedSnapshotSource(WorldSnapshot(
        tickCount: shown.tickCount, simulatedTime: shown.simulatedTime, mapWidth: shown.mapWidth, mapHeight: shown.mapHeight,
        terrainGrid: shown.terrainGrid, occupiedTiles: shown.occupiedTiles, buildings: shown.buildings, carriers: shown.carriers,
        economy: shown.economy, totalPopulation: shown.totalPopulation, camera: Camera(centerX: 5, centerY: 5, zoom: 1),
        housePopulations: shown.housePopulations
    ))
    scene.update(0)
    // The house stands on (2–3, 2–3); its strollers walk the road on row 4, in front of it.
    let houseZ = try #require(scene.buildingNodes[TileCoordinate(x: 2, y: 2)]).zPosition
    let roads = (0 ..< 8).compactMap { scene.buildingNodes[TileCoordinate(x: $0, y: 4)]?.zPosition }
    let roadZ = try #require(roads.max())
    #expect(!scene.strollerNodes.isEmpty)
    for shown in scene.strollerNodes.values {
        #expect(shown.node.zPosition > houseZ && shown.node.zPosition > roadZ)
    }
}
