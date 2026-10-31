import Foundation
import Testing
@testable import CityCore

// Scenarios from openspec/changes/add-event-counterplay (seasonal-events /
// Blight ruins the crops in a marked area; goods-and-production / Crop
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

/// Ticks until `building` completes its next cycle, from a fresh cycle; 0
/// when it completes none in 400 ticks.
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

@Test("scenario: Blighted farm yields nothing")
func blightedFarmYieldsNothing() {
    var (world, field) = blightWorld()
    _ = world.tick()
    #expect(world.seasonalEvents.active?.event == .blight)
    let food = world.stockpiles[field]?.quantity(of: .food)
    let cycle = cycleTicks(of: field, in: &world)
    #expect(cycle.ticks == 0)
    #expect(!cycle.stalled)
    #expect(world.stockpiles[field]?.quantity(of: .food) == food)
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
    #expect(cycle.ticks == 0)
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

/// A town drawing a blight for summer 1203 with `fields` farms and six
/// houses of 4, one tick before the warning.
private func drawnBlightTown(fields: Int) throws -> World {
    let seed = try #require(seedDrawing(SeasonalEventOnset(event: .blight, season: .summer), in: 1203))
    var world = eventsWorld(seed: seed, size: 40)
    for index in 0 ..< fields {
        addOperational(.farm, at: TileCoordinate(x: index * 5, y: 20), in: &world)
    }
    addHouses(6, in: &world)
    _ = runSeasons(&world, untilTick: firstTick(of: .spring, 1203) - 1)
    return world
}

@Test("scenario: A town with six fields is warned of the blight")
func blightWarnsATownWithSixFields() throws {
    var world = try drawnBlightTown(fields: 6)
    let events = runEvents(&world, untilTick: world.tickCount + 2)
    #expect(events.seasonalEvents == [.seasonalEventWarned(event: .blight, onset: .summer)])
}

@Test("scenario: A town with five fields gets a quiet year")
func blightQuietWithFiveFields() throws {
    var world = try drawnBlightTown(fields: 5)
    let events = runEvents(&world, untilTick: world.tickCount + 2)
    #expect(events.seasonalEvents.isEmpty)
    #expect(world.seasonalEvents.plan?.onset == nil)
}

@Test("scenario: A scheduled blight needs one field")
func scheduledBlightNeedsOneField() {
    var world = eventsWorld(seed: 2, size: 30)
    world.seasonalEvents.schedule = [ScheduledSeasonalEvent(year: 1201, event: .blight, onset: .summer)]
    addOperational(.farm, at: TileCoordinate(x: 0, y: 0), in: &world)
    let events = runSeasons(&world, untilTick: firstTick(of: .spring, 1201) + 1)
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

// MARK: - The market answers a blight

@Test("scenario: the market sells more food from a blight's warning to its end")
func marketSellsMoreFoodDuringABlight() {
    var world = eventsWorld(seed: 2, size: 30)
    world.seasonalEvents.schedule = [ScheduledSeasonalEvent(year: 1201, event: .blight, onset: .summer)]
    addOperational(.farm, at: TileCoordinate(x: 0, y: 0), in: &world)
    let center = addOperational(.townCenter, at: TileCoordinate(x: 10, y: 10), in: &world)
    world.economy.balance = 10000
    let usual = Good.food.marketTerms.buyLimit
    #expect(world.marketLeft(.food, .bought) == usual)
    _ = runSeasons(&world, untilTick: firstTick(of: .spring, 1201) + 1)
    #expect(world.seasonalEvents.warned?.event == .blight)
    let relief = usual + World.blightFoodRelief
    #expect(world.marketLeft(.food, .bought) == relief)
    #expect(world.marketQuotes.first { $0.good == .food }?.buyLeft == relief)
    #expect(world.marketLeft(.wood, .bought) == Good.wood.marketTerms.buyLimit)
    world.enqueue(.marketBuy(center, .food, 25))
    _ = world.tick()
    #expect(world.market.traded(.food, .bought) == 25)
    #expect(world.marketLeft(.food, .bought) == relief - 25)
    // The blight's own season gets the relief again, and it ends with the blight.
    _ = runSeasons(&world, untilTick: firstTick(of: .summer, 1201) + 1)
    #expect(world.seasonalEvents.active?.event == .blight)
    #expect(world.marketLeft(.food, .bought) == relief)
    _ = runSeasons(&world, untilTick: firstTick(of: .autumn, 1201) + 1)
    #expect(world.marketLeft(.food, .bought) == usual)
}

// MARK: - The blight's toll

/// The blight world one tick into its season, with an unfed, full house
/// of 4 in the marked area.
private func hungryHouseInABlight() -> (world: World, house: EntityID) {
    var (world, _) = blightWorld()
    _ = world.tick()
    let house = addOperational(.house, at: TileCoordinate(x: 4, y: 4), residents: 4, in: &world)
    return (world, house)
}

@Test("scenario: residents who leave hungry during a blight are its toll")
func hungryResidentsAreTheBlightsToll() {
    var (world, house) = hungryHouseInABlight()
    let events = runEvents(&world, untilTick: firstTick(of: .autumn, 1201))
    let left = 4 - Int(world.populations[house]?.population ?? 0)
    #expect(left > 0)
    #expect(world.seasonalEvents.counters.residentsLeftHungryInBlight == left)
    #expect(events.contains(.seasonalEventEnded(event: .blight, toll: SeasonalEventToll(count: left))))
    #expect(world.seasonalEvents.blight == nil)
}

@Test("scenario: hunger outside a blight is no blight's toll")
func hungerWithoutABlightIsNoToll() {
    var world = eventsWorld(seed: 2, size: 30)
    let house = addOperational(.house, at: TileCoordinate(x: 4, y: 4), residents: 4, in: &world)
    _ = runEvents(&world, untilTick: 600)
    #expect((world.populations[house]?.population ?? 4) < 4)
    #expect(world.seasonalEvents.counters.residentsLeftHungryInBlight == 0)
}

@Test("scenario: a house above its capacity shrinking in a blight is no toll")
func shrinkingAboveCapacityIsNoToll() throws {
    var (world, house) = hungryHouseInABlight()
    world.populations[house]?.population = 12
    world.populations[house]?.addStock(.food, amount: 20)
    world.populations[house]?.addStock(.planks, amount: 20)
    _ = runEvents(&world, untilTick: world.tickCount + 120)
    #expect(try #require(world.populations[house]?.population) < 12)
    #expect(world.seasonalEvents.counters.residentsLeftHungryInBlight == 0)
}

@Test("scenario: a save from before the blight's toll loads with none")
func saveWithoutTheBlightTollLoads() throws {
    var (world, _) = hungryHouseInABlight()
    _ = runEvents(&world, untilTick: world.tickCount + 300)
    var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(world)) as? [String: Any])
    var events = try #require(json["seasonalEvents"] as? [String: Any])
    events["counters"] = ["buildingsLostToFire": 1, "firesPutOut": 2, "residentsLeftWithFever": 3]
    events["blight"] = nil
    json["seasonalEvents"] = events
    let loaded = try JSONDecoder().decode(World.self, from: JSONSerialization.data(withJSONObject: json))
    #expect(loaded.seasonalEvents.counters.residentsLeftWithFever == 3)
    #expect(loaded.seasonalEvents.counters.residentsLeftHungryInBlight == 0)
    #expect(loaded.seasonalEvents.blight == nil)
}

@Test("scenario: a rival's hungry residents are no toll of the player's blight")
func rivalHungerIsNoToll() {
    var (world, _) = blightWorld()
    _ = world.tick()
    let rival = addOperational(.house, at: TileCoordinate(x: 4, y: 4), residents: 4, owner: .rival(1), in: &world)
    _ = runEvents(&world, untilTick: world.tickCount + 300)
    #expect((world.populations[rival]?.population ?? 4) < 4)
    #expect(world.seasonalEvents.counters.residentsLeftHungryInBlight == 0)
}
