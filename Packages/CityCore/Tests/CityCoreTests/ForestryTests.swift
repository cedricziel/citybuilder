import Foundation
import Testing
@testable import CityCore

// Scenarios from openspec/changes/add-forestry: forestry,
// buildings-and-construction and warehouses-and-logistics.

/// An operational building placed directly, bypassing placement rules.
@discardableResult
private func inject(_ kind: BuildingKind, at anchor: TileCoordinate, in world: inout World, owner: Owner = .player) -> EntityID {
    let id = EntityID(raw: world.nextEntityRaw)
    world.nextEntityRaw &+= 1
    world.buildings[id] = Building(id: id, kind: kind, anchor: anchor, state: .operational, owner: owner)
    for tile in BuildingCatalog.spec(for: kind).footprint.tiles(anchor: anchor) {
        world.occupiedTiles[tile] = id
    }
    world.stockpiles[id] = World.newStockpile(for: kind)
    return id
}

private func grassWorld(width: Int = 12, height: Int = 12) -> World {
    World.fixtureWithTerrain(width: width, height: height, fill: .grass, seed: 1)
}

private func setTerrain(_ terrain: TerrainType, at tile: TileCoordinate, in world: inout World) {
    world.terrainGrid[tile.y * world.mapWidth + tile.x] = terrain
}

/// Forest tiles planted by the events.
private func planted(_ events: [WorldEvent]) -> [TileCoordinate] {
    events.compactMap { event in
        if case let .forestPlanted(at, _) = event { return at }
        return nil
    }
}

// MARK: - Forester building

@Test("scenario: forester spec exposes its footprint and costs")
func scenarioForesterSpecExposesItsFootprintAndCosts() {
    let spec = BuildingCatalog.spec(for: .forester)
    #expect(spec.footprint == Footprint(width: 2, height: 2))
    #expect(spec.cost == 60)
    #expect(spec.upkeep == 0)
    #expect(spec.buildDurationTicks == 20)
    #expect(spec.materialCost.isEmpty)
    #expect(BuildingKind.forester.storage == nil)
    #expect(ProductionCatalog.recipe(for: .forester) == nil)
}

@Test("scenario: forester needs no research")
func scenarioForesterNeedsNoResearch() throws {
    var world = World.newGame(layout: .singleIsland, seed: 0, age: .medieval)
    world.economy.credit(10000)
    #expect(Tech.unlocking(.forester) == nil)
    let townCenter = try #require(world.buildings.values.first { $0.kind == .townCenter })
    let island = try #require(world.islandID(at: townCenter.anchor))
    let anchor = world.testFirstTile(onIsland: island) { tile in
        Footprint(width: 2, height: 2).tiles(anchor: tile).allSatisfy {
            world.terrain(at: $0) == .grass && world.occupiedTiles[$0] == nil
        }
    }
    let site = try #require(anchor)
    #expect(world.canPlace(.forester, at: site) == .allowed)
}

// MARK: - Planting

@Test("scenario: forester plants the first open grass tile")
func scenarioForesterPlantsTheFirstOpenGrassTile() {
    var world = grassWorld()
    let forester = inject(.forester, at: TileCoordinate(x: 4, y: 4), in: &world)
    let before = world.testRun(ticks: 39)
    #expect(planted(before).isEmpty)
    let events = world.tick().events
    #expect(world.terrain(at: TileCoordinate(x: 2, y: 2)) == .forest)
    #expect(events.contains(.forestPlanted(at: TileCoordinate(x: 2, y: 2), forester: forester)))
}

@Test("scenario: forester skips occupied and non-grass tiles")
func scenarioForesterSkipsOccupiedAndNonGrassTiles() {
    var world = grassWorld()
    inject(.forester, at: TileCoordinate(x: 4, y: 4), in: &world)
    inject(.road, at: TileCoordinate(x: 2, y: 2), in: &world)
    inject(.house, at: TileCoordinate(x: 3, y: 2), in: &world)
    setTerrain(.beach, at: TileCoordinate(x: 5, y: 2), in: &world)
    setTerrain(.mountain, at: TileCoordinate(x: 6, y: 2), in: &world)
    _ = world.testRun(ticks: 40)
    #expect(world.terrain(at: TileCoordinate(x: 7, y: 2)) == .forest)
    #expect(world.terrain(at: TileCoordinate(x: 2, y: 2)) == .grass)
    #expect(world.terrain(at: TileCoordinate(x: 3, y: 2)) == .grass)
    #expect(world.terrain(at: TileCoordinate(x: 5, y: 2)) == .beach)
    #expect(world.terrain(at: TileCoordinate(x: 6, y: 2)) == .mountain)
}

@Test("scenario: forester without open grass plants nothing")
func scenarioForesterWithoutOpenGrassPlantsNothing() {
    var world = World.fixtureWithTerrain(width: 12, height: 12, fill: .forest, seed: 1)
    setTerrain(.water, at: TileCoordinate(x: 2, y: 2), in: &world)
    inject(.forester, at: TileCoordinate(x: 4, y: 4), in: &world)
    let terrain = world.terrainGrid
    let events = world.testRun(ticks: 80)
    #expect(planted(events).isEmpty)
    #expect(world.terrainGrid == terrain)
}

@Test("scenario: forester works without a road")
func scenarioForesterWorksWithoutARoad() {
    var world = grassWorld()
    inject(.forester, at: TileCoordinate(x: 4, y: 4), in: &world)
    let events = world.testRun(ticks: 40)
    #expect(planted(events).count == 1)
    #expect(world.terrainGrid.count { $0 == .forest } == 1)
}

@Test("scenario: forester and lumberjack hut sustain each other")
func scenarioForesterAndLumberjackHutSustainEachOther() {
    var world = grassWorld(width: 14, height: 12)
    let hut = inject(.lumberjackHut, at: TileCoordinate(x: 4, y: 4), in: &world)
    inject(.forester, at: TileCoordinate(x: 7, y: 4), in: &world)
    var cycles = 0
    var harvested = false
    var bareStreak = 0
    var longestBareStreak = 0
    for _ in 0 ..< 2400 {
        let events = world.tick().events
        cycles += events.count { $0 == .productionCycleCompleted(producer: hut, kind: .lumberjackHut) }
        world.stockpiles[hut] = Stockpile(capacity: 16)
        harvested = harvested || cycles > 0
        let trees = world.forestTiles(inCatchmentOf: .lumberjackHut, at: TileCoordinate(x: 4, y: 4))
        bareStreak = harvested && trees == 0 ? bareStreak + 1 : 0
        longestBareStreak = max(longestBareStreak, bareStreak)
    }
    #expect(cycles >= 50)
    #expect(longestBareStreak <= 40)
}

@Test("scenario: forester never plants on a rival island")
func scenarioForesterNeverPlantsOnARivalIsland() throws {
    var world = World.fixtureWithTerrain(width: 12, height: 8, fill: .forest, seed: 1)
    for y in 0 ..< 8 {
        setTerrain(.water, at: TileCoordinate(x: 6, y: y), in: &world)
        for x in 7 ..< 12 {
            setTerrain(.grass, at: TileCoordinate(x: x, y: y), in: &world)
        }
    }
    let rivalIsland = try #require(world.islandID(at: TileCoordinate(x: 9, y: 3)))
    world.rivals = [RivalTown(
        id: 1, name: "Ravenshore", islandID: rivalIsland, culture: .mediterranean, colour: .crimson,
        age: world.age, treasury: 0, townCenterID: EntityID(raw: 9999), ai: RivalAIState()
    )]
    inject(.forester, at: TileCoordinate(x: 4, y: 2), in: &world)
    let events = world.testRun(ticks: 120)
    #expect(planted(events).isEmpty)
    #expect((0 ..< 8).allSatisfy { world.terrain(at: TileCoordinate(x: 7, y: $0)) == .grass })
}

// MARK: - Winter

/// Ticks until a fresh forester cycle started on the first winter tick
/// plants its tile.
private func winterPlantingTicks(calendarActive: Bool) throws -> Int {
    var world = World.fixtureWithTerrain(width: 10, height: 10, fill: .grass, seed: 1)
    world.calendar = CalendarState(startYear: 1200, isActive: calendarActive)
    let forester = inject(.forester, at: TileCoordinate(x: 4, y: 4), in: &world)
    while world.tickCount < 3 * CalendarState.ticksPerSeason - 1 {
        world.tick()
        world.terrainGrid = Array(repeating: .grass, count: 100)
    }
    world.productions[forester] = ProductionProgress()
    for elapsed in 1 ... 200 where !planted(world.tick().events).isEmpty {
        return elapsed
    }
    return -1
}

@Test("scenario: forester takes twice as long in winter")
func scenarioForesterTakesTwiceAsLongInWinter() throws {
    #expect(try winterPlantingTicks(calendarActive: true) == 80)
}

@Test("scenario: forester ignores winter with the calendar inactive")
func scenarioForesterIgnoresWinterWithTheCalendarInactive() throws {
    #expect(try winterPlantingTicks(calendarActive: false) == 40)
}

// MARK: - Trees and open ground in reach

@Test("scenario: snapshot carries trees in reach for a hut")
func scenarioSnapshotCarriesTreesInReachForAHut() {
    var world = grassWorld()
    let hut = inject(.lumberjackHut, at: TileCoordinate(x: 4, y: 4), in: &world)
    for x in 2 ..< 9 {
        setTerrain(.forest, at: TileCoordinate(x: x, y: 2), in: &world)
    }
    setTerrain(.forest, at: TileCoordinate(x: 3, y: 7), in: &world)
    #expect(world.snapshot().catchments[hut] == 7)
}

@Test("scenario: snapshot carries open ground for a forester")
func scenarioSnapshotCarriesOpenGroundForAForester() {
    var world = World.fixtureWithTerrain(width: 12, height: 12, fill: .forest, seed: 1)
    let forester = inject(.forester, at: TileCoordinate(x: 4, y: 4), in: &world)
    for x in 2 ..< 8 {
        setTerrain(.grass, at: TileCoordinate(x: x, y: 2), in: &world)
        setTerrain(.grass, at: TileCoordinate(x: x, y: 3), in: &world)
    }
    #expect(world.snapshot().catchments[forester] == 12)
}

@Test("scenario: catchment preview for an unbuilt hut")
func scenarioCatchmentPreviewForAnUnbuiltHut() {
    var world = grassWorld()
    for x in 2 ..< 8 {
        setTerrain(.forest, at: TileCoordinate(x: x, y: 2), in: &world)
    }
    for x in 2 ..< 5 {
        setTerrain(.forest, at: TileCoordinate(x: x, y: 7), in: &world)
    }
    setTerrain(.forest, at: TileCoordinate(x: 9, y: 9), in: &world)
    let before = world
    #expect(world.catchmentCount(kind: .lumberjackHut, anchor: TileCoordinate(x: 4, y: 4), owner: .player) == 9)
    #expect(world == before)
}

// MARK: - Building issues

@Test("scenario: a forester without open grass reports no room to plant")
func scenarioAForesterWithoutOpenGrassReportsNoRoomToPlant() {
    var world = World.fixtureWithTerrain(width: 12, height: 12, fill: .forest, seed: 1)
    let forester = inject(.forester, at: TileCoordinate(x: 4, y: 4), in: &world)
    #expect(world.buildingIssues()[forester] == .noRoomToPlant)
}

@Test("scenario: a forester without a road reports no issue")
func scenarioAForesterWithoutARoadReportsNoIssue() {
    var world = grassWorld()
    let forester = inject(.forester, at: TileCoordinate(x: 4, y: 4), in: &world)
    #expect(world.buildingIssues()[forester] == nil)
}

@Test func onlyHutsAndForestersHaveACatchment() {
    let world = grassWorld()
    #expect(world.catchmentCount(kind: .house, anchor: TileCoordinate(x: 4, y: 4), owner: .player) == 0)
}

@Test func forestPlantedNamesItsForesterButNoKind() {
    let event = WorldEvent.forestPlanted(at: TileCoordinate(x: 1, y: 2), forester: EntityID(raw: 7))
    #expect(event.primaryEntityID == EntityID(raw: 7))
    #expect(event.buildingKind == nil)
}

@Test("scenario: hut and forester declare their radius")
func catchmentRadiusIsGameData() {
    #expect(BuildingKind.lumberjackHut.catchmentRadius == 2)
    #expect(BuildingKind.forester.catchmentRadius == 2)
    #expect(BuildingKind.sawmill.catchmentRadius == nil)
}

@Test("scenario: the catchment follows the declared radius")
func catchmentEndsAtTheRadius() {
    var world = World.fixtureWithTerrain(width: 12, height: 12, fill: .grass, seed: 1)
    // A 2×2 hut at (4, 4): (2, 4) is 2 tiles from its footprint, (1, 4) is 3.
    world.terrainGrid[4 * world.mapWidth + 2] = .forest
    world.terrainGrid[4 * world.mapWidth + 1] = .forest
    #expect(world.catchmentCount(kind: .lumberjackHut, anchor: TileCoordinate(x: 4, y: 4), owner: .player) == 1)
}
