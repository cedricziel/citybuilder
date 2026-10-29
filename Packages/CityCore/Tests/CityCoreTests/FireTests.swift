import Foundation
import Testing
@testable import CityCore

// Scenarios from openspec/changes/add-event-counterplay (seasonal-events /
// Fire starts, spreads and burns down; A fire watch puts out fires in
// reach; buildings-and-construction / Ruins block their plot until cleared).

/// A world with a fire event under way and no ignitions left to come, so
/// a test lights the fires itself.
private func fireWorld(difficulty: Difficulty = .normal) -> World {
    var world = eventsWorld(difficulty: difficulty, size: 24)
    world.tickCount = firstTick(of: .summer, 1202)
    world.seasonalEvents.active = ActiveSeasonalEvent(
        event: .fire, startTick: world.tickCount, lastTick: firstTick(of: .winter, 1202) - 1
    )
    world.seasonalEvents.fire = FireEventState(ignitionTicks: [])
    return world
}

private func road(_ tiles: [TileCoordinate], in world: inout World) {
    for tile in tiles {
        SignatureFixture.inject(.road, at: tile, in: &world)
        world.roadGraph.addRoad(at: tile)
    }
}

private func light(_ id: EntityID, in world: inout World) -> UInt64 {
    var events: [WorldEvent] = []
    world.ignite(id, events: &events)
    // Within a tick the fire system sends a watchman on the tick of the ignition.
    world.dispatchWatchmen()
    return world.tickCount
}

private func run(_ world: inout World, ticks: UInt64) -> [WorldEvent] {
    runEvents(&world, untilTick: world.tickCount + ticks)
}

private func isBurning(_ id: EntityID, in world: World) -> Bool {
    world.buildings[id]?.state == .burning
}

/// A fire watch at (1, 2) whose only road runs down, along y = 4 and up
/// to (8, 3): ten tiles to the house at (8, 1).
private func watchAndHouse(in world: inout World) -> (watch: EntityID, house: EntityID) {
    let tiles = [TileCoordinate(x: 1, y: 3)] + (1 ... 8).map { TileCoordinate(x: $0, y: 4) } + [TileCoordinate(x: 8, y: 3)]
    road(tiles, in: &world)
    let watch = addOperational(.fireWatch, at: TileCoordinate(x: 1, y: 2), in: &world)
    let house = addOperational(.house, at: TileCoordinate(x: 8, y: 1), residents: 4, in: &world)
    return (watch, house)
}

@Test("scenario: Fire spreads to a touching house")
func fireSpreadsToATouchingHouse() {
    var world = fireWorld()
    let first = addOperational(.house, at: TileCoordinate(x: 0, y: 0), residents: 2, in: &world)
    let second = addOperational(.house, at: TileCoordinate(x: 2, y: 0), residents: 2, in: &world)
    _ = light(first, in: &world)
    let before = run(&world, ticks: 149)
    #expect(!isBurning(second, in: world))
    #expect(!before.contains(.buildingCaughtFire(building: second, kind: .house)))
    let spread = run(&world, ticks: 1)
    #expect(spread.contains(.buildingCaughtFire(building: second, kind: .house)))
    #expect(isBurning(second, in: world))
}

@Test("scenario: Hard fire spreads sooner")
func hardFireSpreadsSooner() {
    var world = fireWorld(difficulty: .hard)
    let first = addOperational(.house, at: TileCoordinate(x: 0, y: 0), in: &world)
    let second = addOperational(.house, at: TileCoordinate(x: 0, y: 2), in: &world)
    _ = light(first, in: &world)
    _ = run(&world, ticks: 100)
    #expect(isBurning(second, in: world))
}

@Test("scenario: A road is a firebreak")
func roadIsAFirebreak() {
    var world = fireWorld()
    let first = addOperational(.house, at: TileCoordinate(x: 0, y: 0), in: &world)
    road([TileCoordinate(x: 2, y: 0), TileCoordinate(x: 2, y: 1)], in: &world)
    let across = addOperational(.house, at: TileCoordinate(x: 3, y: 0), in: &world)
    _ = light(first, in: &world)
    let events = run(&world, ticks: 400)
    #expect(world.buildings[across]?.state == .operational)
    #expect(events.contains(.buildingBurntDown(building: first, kind: .house)))
}

@Test("scenario: An unanswered fire leaves ruins")
func unansweredFireLeavesRuins() throws {
    var world = fireWorld()
    let house = addOperational(.house, at: TileCoordinate(x: 0, y: 0), residents: 4, in: &world)
    world.stockpiles[house]?.deposit(.food, amount: 3)
    _ = light(house, in: &world)
    _ = run(&world, ticks: 299)
    #expect(isBurning(house, in: world))
    _ = run(&world, ticks: 1)
    let ruins = try #require(world.buildings[house])
    #expect(ruins.kind == .ruins && ruins.ruinOf == .house)
    #expect(ruins.footprint == Footprint(width: 2, height: 2))
    #expect(world.populations[house] == nil)
    #expect(world.stockpiles[house] == nil)
    #expect(world.seasonalEvents.counters.buildingsLostToFire == 1)
}

@Test("scenario: Doused buildings don't catch again")
func dousedBuildingsDontCatchAgain() {
    var world = fireWorld()
    let first = addOperational(.house, at: TileCoordinate(x: 0, y: 0), in: &world)
    let second = addOperational(.house, at: TileCoordinate(x: 2, y: 0), in: &world)
    _ = light(first, in: &world)
    _ = run(&world, ticks: 150)
    #expect(isBurning(second, in: world))
    _ = run(&world, ticks: 10)
    var events: [WorldEvent] = []
    world.extinguish(first, events: &events)
    // The second fire reaches its own spread time 150 ticks after it caught.
    _ = run(&world, ticks: 150)
    #expect(world.buildings[first]?.state == .operational)
}

@Test("scenario: A watch saves a house")
func watchSavesAHouse() {
    var world = fireWorld()
    let (_, house) = watchAndHouse(in: &world)
    let ignition = light(house, in: &world)
    _ = run(&world, ticks: 39)
    #expect(isBurning(house, in: world))
    let out = run(&world, ticks: 1)
    #expect(out.contains(.fireExtinguished(building: house)))
    #expect(world.tickCount == ignition + 40)
    #expect(world.buildings[house]?.state == .operational)
    #expect(world.populations[house]?.population == 4)
    #expect(world.seasonalEvents.counters.firesPutOut == 1)
}

@Test("scenario: the watchman walks the road as a walker")
func watchmanIsAWalker() throws {
    var world = fireWorld()
    let (watch, house) = watchAndHouse(in: &world)
    _ = light(house, in: &world)
    _ = run(&world, ticks: 4)
    let walker = try #require(world.snapshot().carriers.first { $0.id == watch })
    #expect(walker.currentTile == TileCoordinate(x: 4, y: 4))
    _ = run(&world, ticks: 10)
    #expect(!world.snapshot().carriers.contains { $0.id == watch })
}

@Test("scenario: A watch finished during the fire")
func watchFinishedDuringTheFire() {
    var world = fireWorld()
    road((0 ... 4).map { TileCoordinate(x: $0, y: 2) }, in: &world)
    let house = addOperational(.house, at: TileCoordinate(x: 4, y: 0), in: &world)
    _ = light(house, in: &world)
    _ = run(&world, ticks: 59)
    let site = SignatureFixture.inject(.fireWatch, at: TileCoordinate(x: 0, y: 1), in: &world, state: .constructing)
    world.buildings[site]?.ticksSincePlacement = BuildingCatalog.spec(for: .fireWatch).buildDurationTicks - 1
    let built = run(&world, ticks: 1)
    #expect(built.contains { if case .constructionCompleted = $0 { true } else { false } })
    let sentAt = world.tickCount
    let walk = UInt64(world.seasonalEvents.fire?.fires.first?.watchman?.path.count ?? 0)
    #expect(walk == 5)
    _ = run(&world, ticks: 34)
    #expect(isBurning(house, in: world))
    _ = run(&world, ticks: 1)
    #expect(world.buildings[house]?.state == .operational)
    #expect(world.tickCount == sentAt + 35)
}

@Test("scenario: Out of reach")
func outOfReach() {
    var world = fireWorld()
    road((0 ... 11).map { TileCoordinate(x: $0, y: 2) }, in: &world)
    addOperational(.fireWatch, at: TileCoordinate(x: 0, y: 1), in: &world)
    let house = addOperational(.house, at: TileCoordinate(x: 10, y: 0), in: &world)
    _ = light(house, in: &world)
    _ = run(&world, ticks: 1)
    #expect(world.seasonalEvents.fire?.fires.first?.watchman == nil)
}

@Test("scenario: a watch answers one fire at a time, oldest first")
func watchAnswersOneFireAtATime() {
    var world = fireWorld()
    road((0 ... 8).map { TileCoordinate(x: $0, y: 2) }, in: &world)
    addOperational(.fireWatch, at: TileCoordinate(x: 0, y: 1), in: &world)
    let near = addOperational(.house, at: TileCoordinate(x: 3, y: 0), in: &world)
    let far = addOperational(.house, at: TileCoordinate(x: 7, y: 0), in: &world)
    _ = light(far, in: &world)
    _ = run(&world, ticks: 1)
    _ = light(near, in: &world)
    let firstOut = run(&world, ticks: 60)
    #expect(firstOut.contains(.fireExtinguished(building: far)))
    #expect(isBurning(near, in: world))
    _ = run(&world, ticks: 40)
    #expect(world.buildings[near]?.state == .operational)
}

@Test("scenario: a burning building stops")
func burningBuildingStops() {
    var world = fireWorld()
    let farm = addOperational(.farm, at: TileCoordinate(x: 0, y: 0), in: &world)
    let house = addOperational(.house, at: TileCoordinate(x: 5, y: 0), residents: 4, in: &world)
    _ = light(farm, in: &world)
    _ = light(house, in: &world)
    _ = run(&world, ticks: 100)
    #expect(world.productions[farm] == nil)
    #expect(world.playerTaxAndUpkeep.tax == 0)
}

@Test("scenario: The target burnt before Hard's second ignition")
func secondIgnitionWithoutCandidates() {
    var world = eventsWorld(difficulty: .hard, size: 12)
    world.seasonalEvents.schedule = [ScheduledSeasonalEvent(year: 1201, event: .fire, onset: .summer)]
    let house = addOperational(.house, at: TileCoordinate(x: 0, y: 0), in: &world)
    let events = runSeasons(&world, untilTick: firstTick(of: .summer, 1201))
    #expect(events.seasonalEvents == [.seasonalEventWarned(event: .fire, onset: .summer), .seasonalEventStarted(event: .fire)])
    let ignitions = world.seasonalEvents.fire?.ignitionTicks ?? []
    #expect(ignitions.count == 2)
    let rest = runEvents(&world, untilTick: firstTick(of: .autumn, 1201))
    #expect(rest.contains(.buildingCaughtFire(building: house, kind: .house)))
    #expect(rest.contains(.seasonalEventEnded(event: .fire, toll: SeasonalEventToll(count: 1, fires: 1))))
    #expect(world.seasonalEvents.fire == nil)
}

@Test("scenario: no fire broke out")
func noFireBrokeOut() {
    var world = eventsWorld(size: 12)
    world.seasonalEvents.schedule = [ScheduledSeasonalEvent(year: 1201, event: .fire, onset: .summer)]
    let house = addOperational(.house, at: TileCoordinate(x: 0, y: 0), in: &world)
    _ = runSeasons(&world, untilTick: firstTick(of: .summer, 1201))
    // The house is gone before the ignition.
    world.enqueue(.demolish(at: TileCoordinate(x: 0, y: 0)))
    let rest = runEvents(&world, untilTick: firstTick(of: .autumn, 1201))
    #expect(world.buildings[house] == nil)
    #expect(rest.contains(.seasonalEventEnded(event: .fire, toll: SeasonalEventToll(count: 0, fires: 0))))
}

@Test("scenario: the rains put out what still burns")
func rainsPutOutTheFires() {
    var world = fireWorld()
    let house = addOperational(.house, at: TileCoordinate(x: 0, y: 0), in: &world)
    world.seasonalEvents.active = ActiveSeasonalEvent(event: .fire, startTick: world.tickCount, lastTick: world.tickCount + 50)
    _ = light(house, in: &world)
    let events = run(&world, ticks: 50)
    #expect(events.contains(.fireExtinguished(building: house)))
    #expect(events.contains(.seasonalEventEnded(event: .fire, toll: SeasonalEventToll(count: 0, fires: 1))))
    #expect(world.buildings[house]?.state == .operational)
}

@Test("scenario: a demolished fire goes with its building")
func demolishedBurningBuilding() {
    var world = fireWorld()
    let house = addOperational(.house, at: TileCoordinate(x: 0, y: 0), in: &world)
    let other = addOperational(.house, at: TileCoordinate(x: 6, y: 0), in: &world)
    _ = light(house, in: &world)
    _ = light(other, in: &world)
    world.enqueue(.demolish(at: TileCoordinate(x: 0, y: 0)))
    _ = run(&world, ticks: 1)
    #expect(world.seasonalEvents.fire?.fires.map(\.building) == [other])
}

@Test("scenario: Clearing a burnt house")
func clearingABurntHouse() {
    var world = fireWorld()
    let house = addOperational(.house, at: TileCoordinate(x: 0, y: 0), in: &world)
    _ = light(house, in: &world)
    _ = run(&world, ticks: 300)
    world.economy.balance = 100
    world.enqueue(.demolish(at: TileCoordinate(x: 1, y: 1)))
    let events = run(&world, ticks: 1)
    #expect(events.contains(.ruinsCleared(building: house)))
    #expect(world.economy.balance == 85)
    #expect(world.occupiedTiles[TileCoordinate(x: 1, y: 1)] == nil)
}

@Test("scenario: clearing ruins the treasury can't pay")
func clearingWithoutMoney() {
    var world = fireWorld()
    let house = addOperational(.house, at: TileCoordinate(x: 0, y: 0), in: &world)
    _ = light(house, in: &world)
    _ = run(&world, ticks: 300)
    world.economy.balance = 10
    world.enqueue(.demolish(at: TileCoordinate(x: 0, y: 0)))
    let events = run(&world, ticks: 1)
    #expect(events.contains(.demolitionRejected(building: house, reason: .notEnoughMoney)))
    #expect(world.buildings[house]?.kind == .ruins)
    #expect(world.economy.balance == 10)
}

@Test("scenario: Building on ruins is rejected")
func buildingOnRuinsIsRejected() {
    var world = fireWorld()
    let house = addOperational(.house, at: TileCoordinate(x: 0, y: 0), in: &world)
    _ = light(house, in: &world)
    _ = run(&world, ticks: 300)
    #expect(world.canPlace(.house, at: TileCoordinate(x: 1, y: 1)) == .rejected(.tileOccupied))
}

@Test func clearingFeesFollowTheBurntKind() {
    let fees = [BuildingKind.house, .sawmill, .warehouse, .road].map(World.clearingFee(of:))
    #expect(fees == [15, 30, 50, 10])
}

@Test("scenario: A fire survives a save and load")
func fireSurvivesASave() throws {
    var world = fireWorld()
    let (_, house) = watchAndHouse(in: &world)
    let ignition = light(house, in: &world)
    _ = run(&world, ticks: 5)
    let saved = try JSONEncoder().encode(world)
    var loaded = try JSONDecoder().decode(World.self, from: saved)
    #expect(loaded == world)
    _ = runEvents(&loaded, untilTick: ignition + 40)
    #expect(loaded.buildings[house]?.state == .operational)
}

@Test func fireWorldEventsCompare() {
    let id = EntityID(raw: 7)
    let events: [WorldEvent] = [
        .buildingCaughtFire(building: id, kind: .house), .fireExtinguished(building: id),
        .buildingBurntDown(building: id, kind: .house), .ruinsCleared(building: id),
        .demolitionRejected(building: id, reason: .notEnoughMoney)
    ]
    #expect(events.map(\.caseOrdinal) == [39, 40, 41, 42, 43])
    #expect(events.allSatisfy { $0.primaryEntityID == id })
    let kinds = events.compactMap(\.buildingKind)
    #expect(kinds == [.house, .house])
    #expect(events[0] != .buildingCaughtFire(building: id, kind: .farm))
    #expect(events[3] != .ruinsCleared(building: EntityID(raw: 8)))
}

@Test("scenario: a burning store gives no building materials")
func burningStoreGivesNoMaterials() {
    var world = fireWorld()
    world.testMaterialCredits = [:]
    world.islands = IslandDetector.detectIslands(width: 24, height: 24, terrain: world.terrainGrid, mapHeightForClimate: 24, seed: 1)
    let store = addOperational(.warehouse, at: TileCoordinate(x: 0, y: 0), in: &world)
    world.stockpiles[store]?.deposit(.planks, amount: 10)
    let anchor = TileCoordinate(x: 10, y: 10)
    #expect(world.canPlace(.house, at: anchor) == .allowed)
    world.buildings[store]?.state = .burning
    #expect(world.canPlace(.house, at: anchor) == .rejected(.insufficientMaterials([.planks: 4])))
    world.enqueue(.place(.house, at: anchor))
    _ = run(&world, ticks: 1)
    #expect(world.stockpiles[store]?.quantity(of: .planks) == 10)
}
