import Foundation
import Testing
@testable import CityCore

// Scenarios from openspec/changes/add-event-counterplay (seasonal-events /
// Blight halves crop yields in a marked area; goods-and-production / Crop
// fields are marked in the game data).

/// A world one tick before a scheduled blight in summer 1201 starts, with
/// a farm at (0, 0) as the only crop field when it was warned.
private func blightWorld() -> (world: World, field: EntityID) {
    var world = eventsWorld(seed: 2, size: 30)
    world.seasonalEvents.schedule = [ScheduledSeasonalEvent(year: 1201, event: .blight, onset: .summer)]
    let field = addOperational(.farm, at: TileCoordinate(x: 0, y: 0), in: &world)
    _ = runSeasons(&world, untilTick: firstTick(of: .summer, 1201) - 1)
    return (world, field)
}

/// Ticks until `building` completes its next cycle, from a fresh cycle. A
/// slowed field counts every other tick, as in winter, so its 40-tick cycle
/// takes 79 or 80 ticks by the parity of the tick it starts on.
private func cycleTicks(of building: EntityID, in world: inout World) -> (ticks: UInt64, stalled: Bool) {
    world.productions[building] = ProductionProgress()
    var stalled = false
    for ticks in UInt64(1) ... 400 {
        let events = world.tick().events
        if events.contains(.productionStalled(producer: building, kind: world.buildings[building]!.kind)) { stalled = true }
        if events.contains(where: { if case .productionCycleCompleted(building, _) = $0 { true } else { false } }) {
            return (ticks, stalled)
        }
    }
    return (0, stalled)
}

@Test("scenario: the blight marks the area around a crop field at its warning")
func blightMarksAnArea() throws {
    let (world, field) = blightWorld()
    let area = try #require(world.seasonalEvents.marked)
    let farm = try #require(world.buildings[field])
    #expect(area.around == farm.bounds)
    #expect(area.radius == 6)
    #expect(world.snapshot().markedArea == area)
}

@Test("scenario: Blighted farm takes twice as long")
func blightedFarmTakesTwiceAsLong() {
    var (world, field) = blightWorld()
    _ = world.tick()
    #expect(world.seasonalEvents.active?.event == .blight)
    let cycle = cycleTicks(of: field, in: &world)
    #expect((79 ... 80).contains(cycle.ticks))
    #expect(!cycle.stalled)
    #expect(world.snapshot().blightedFields.contains(field))
}

@Test("scenario: Farm outside the area")
func farmOutsideTheArea() {
    var (world, _) = blightWorld()
    // Seven tiles from the blighted field's footprint, which ends at x = 1.
    let far = addOperational(.farm, at: TileCoordinate(x: 9, y: 0), in: &world)
    _ = world.tick()
    let cycle = cycleTicks(of: far, in: &world)
    #expect(cycle.ticks == 40)
}

@Test("scenario: The sheep farm is not a crop")
func sheepFarmIsNotBlighted() {
    var (world, _) = blightWorld()
    let sheep = addOperational(.sheepFarm, at: TileCoordinate(x: 3, y: 0), in: &world)
    _ = world.tick()
    let cycle = cycleTicks(of: sheep, in: &world)
    #expect(cycle.ticks == 40)
}

@Test("scenario: a field built in the area during the blight is blighted too")
func newFieldInTheAreaIsBlighted() {
    var (world, _) = blightWorld()
    _ = world.tick()
    let late = addOperational(.grainFarm, at: TileCoordinate(x: 3, y: 3), in: &world)
    let cycle = cycleTicks(of: late, in: &world)
    #expect((79 ... 80).contains(cycle.ticks))
}

@Test("scenario: the blight ends with its season and leaves the area")
func blightEndsAndClearsTheArea() {
    var (world, field) = blightWorld()
    let events = runEvents(&world, untilTick: firstTick(of: .autumn, 1201))
    #expect(events.contains(.seasonalEventEnded(event: .blight, toll: SeasonalEventToll(count: 0))))
    #expect(world.seasonalEvents.marked == nil)
    let cycle = cycleTicks(of: field, in: &world)
    #expect(cycle.ticks == 40)
}

@Test("scenario: the marked area shows in the amber threat style, its crop fields as targets")
func markedAreaShowsAsAThreat() throws {
    var (world, field) = blightWorld()
    addOperational(.sheepFarm, at: TileCoordinate(x: 3, y: 0), in: &world)
    let area = try #require(world.threatenedArea())
    #expect(area.style == .threat)
    // Six tiles around the 2×2 field at the map's corner.
    #expect(area.tiles.count == 8 * 8)
    let farm = try #require(world.buildings[field])
    #expect(Set(area.targets) == Set(farm.footprint.tiles(anchor: farm.anchor)))
    #expect(!area.targets.contains(TileCoordinate(x: 3, y: 0)))
    #expect(eventsWorld().threatenedArea() == nil)
}

@Test("scenario: a save in the middle of a blight plays on the same")
func blightSurvivesASaveAndLoad() throws {
    var (world, _) = blightWorld()
    _ = runEvents(&world, untilTick: world.tickCount + 50)
    #expect(world.seasonalEvents.active?.event == .blight)
    var loaded = try JSONDecoder().decode(World.self, from: JSONEncoder().encode(world))
    #expect(loaded.seasonalEvents == world.seasonalEvents)
    let original = runEvents(&world, untilTick: world.tickCount + 200)
    let reloaded = runEvents(&loaded, untilTick: loaded.tickCount + 200)
    #expect(reloaded == original)
    #expect(loaded.productions == world.productions)
}

// MARK: - When a blight may come (design D10)

@Test("scenario: No blight before year 4")
func noBlightBeforeYear4() {
    for difficulty in [Difficulty.normal, .hard] {
        let blights = { (year: Int) in
            (UInt64(0) ..< 300)
                .filter { eventsWorld(seed: $0, difficulty: difficulty, size: 1).seasonalEvent(forYear: year)?.event == .blight }
        }
        let early = blights(1202)
        let later = blights(1203)
        #expect(early.isEmpty, "\(difficulty)")
        #expect(!later.isEmpty, "\(difficulty)")
    }
    #expect(SeasonalEvent.blight.firstYear == 4)
}

/// A town drawing a blight for summer 1203, with a farm, six houses of 4
/// and a warehouse holding `food`, one tick before the warning.
private func drawnBlightTown(food: Int) throws -> World {
    let seed = try #require(seedDrawing(SeasonalEventOnset(event: .blight, season: .summer), in: 1203))
    var world = eventsWorld(seed: seed, size: 30)
    addOperational(.farm, at: TileCoordinate(x: 20, y: 20), in: &world)
    addHouses(6, in: &world)
    let store = addOperational(.warehouse, at: TileCoordinate(x: 20, y: 10), in: &world)
    world.stockpiles[store]?.deposit(.food, amount: food)
    _ = runSeasons(&world, untilTick: firstTick(of: .spring, 1203) - 1)
    return world
}

@Test("scenario: A town with nothing stored gets a quiet year")
func blightNeedsFoodStored() throws {
    var world = try drawnBlightTown(food: 0)
    let events = runEvents(&world, untilTick: world.tickCount + 2)
    #expect(events.seasonalEvents.isEmpty)
    #expect(world.seasonalEvents.plan?.onset == nil)
}

@Test("scenario: A town with a season of food stored is warned of the blight")
func blightWarnsAStockedTown() throws {
    var world = try drawnBlightTown(food: 0)
    let draw = world.seasonFoodDraw()
    let store = try #require(world.buildings.values.first { $0.kind == .warehouse })
    world.stockpiles[store.id]?.deposit(.food, amount: draw)
    let events = runEvents(&world, untilTick: world.tickCount + 2)
    #expect(draw > 0)
    #expect(events.seasonalEvents == [.seasonalEventWarned(event: .blight, onset: .summer)])
}

@Test("scenario: a field still being built is not blighted")
func fieldUnderConstructionIsNotBlighted() throws {
    var (world, _) = blightWorld()
    _ = world.tick()
    let site = addOperational(.farm, at: TileCoordinate(x: 3, y: 0), in: &world)
    world.buildings[site]?.state = .constructing
    let building = try #require(world.buildings[site])
    #expect(!world.isBlighted(building))
    #expect(!world.snapshot().blightedFields.contains(site))
}
