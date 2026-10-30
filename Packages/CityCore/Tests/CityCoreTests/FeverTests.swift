import Foundation
import Testing
@testable import CityCore

// Scenarios from openspec/changes/add-event-counterplay (seasonal-events /
// Fever holds a district back; buildings-and-construction / Physician and
// herb garden; goods-and-production / Herbs).

/// Six peasant houses of 4 in a row at y = 0, the first at (0, 0), and a
/// fever scheduled for autumn 1201, one tick before it is warned in summer.
private func feverWorld(difficulty: Difficulty = .normal) -> World {
    var world = eventsWorld(seed: 4, difficulty: difficulty, size: 40)
    world.seasonalEvents.schedule = [ScheduledSeasonalEvent(year: 1201, event: .fever, onset: .autumn)]
    addHouses(6, in: &world)
    _ = runSeasons(&world, untilTick: firstTick(of: .summer, 1201) - 1)
    return world
}

/// A merchant house of 8 at (30, 30), far from the others, made the fever's
/// district.
private func merchantHouse(in world: inout World) -> EntityID {
    let id = addOperational(.house, at: TileCoordinate(x: 30, y: 30), residents: 8, in: &world)
    world.populations[id]?.tier = .merchants
    world.populations[id]?.population = 8
    if let house = world.buildings[id] {
        world.seasonalEvents.marked = MarkedArea(around: house.bounds, radius: 6)
    }
    return id
}

/// Ticks to `tick` with the house's stock and every physician's herbs kept
/// full, as porters and carriers would, so nothing but the fever moves it.
private func runTended(_ world: inout World, house: EntityID, untilTick tick: UInt64) -> [WorldEvent] {
    var events: [WorldEvent] = []
    while world.tickCount < tick {
        for good in HouseTier.allNeeds(in: world.culture) {
            _ = world.populations[house]?.addStock(good, amount: 1000)
        }
        for physician in world.buildings.values where physician.kind == .physician {
            world.stockpiles[physician.id]?.deposit(.herbs, amount: 8)
        }
        events += world.tick().events
    }
    return events
}

@Test("scenario: the fever marks a district around a house at its warning")
func feverMarksADistrict() throws {
    var world = feverWorld()
    let events = world.tick().events
    #expect(events.seasonalEvents == [.seasonalEventWarned(event: .fever, onset: .autumn)])
    let area = try #require(world.seasonalEvents.marked)
    #expect(area.radius == 6)
    let houses = world.buildings.values.filter { $0.kind == .house }
    #expect(houses.contains { $0.bounds == area.around })
}

@Test("scenario: Fever empties a house")
func feverEmptiesAHouse() {
    var world = feverWorld()
    _ = world.tick()
    let house = merchantHouse(in: &world)
    let onset = firstTick(of: .autumn, 1201)
    let events = runTended(&world, house: house, untilTick: onset + CalendarState.ticksPerSeason)
    let left = events.count { $0 == .residentLeftWithFever(house: house) }
    #expect(left == 3)
    #expect(world.populations[house]?.tier == .merchants)
    #expect(world.seasonalEvents.counters.residentsLeftWithFever >= 3)
    let ended = events.first { if case .seasonalEventEnded(.fever, _) = $0 { true } else { false } }
    #expect(ended != nil)
}

@Test("scenario: Hard empties faster")
func hardFeverEmptiesFaster() {
    var world = feverWorld(difficulty: .hard)
    _ = world.tick()
    let house = merchantHouse(in: &world)
    let events = runTended(&world, house: house, untilTick: firstTick(of: .autumn, 1201) + CalendarState.ticksPerSeason)
    #expect(events.count { $0 == .residentLeftWithFever(house: house) } == 4)
}

@Test("scenario: a house with one resident keeps them")
func lastResidentStays() {
    var world = feverWorld()
    _ = world.tick()
    let house = merchantHouse(in: &world)
    world.populations[house]?.tier = .peasants
    world.populations[house]?.population = 1
    // Unstocked, so it can't grow back to two.
    let events = runEvents(&world, untilTick: firstTick(of: .autumn, 1201) + CalendarState.ticksPerSeason)
    #expect(!events.contains(.residentLeftWithFever(house: house)))
}

@Test("scenario: A physician spares the house")
func physicianSparesTheHouse() {
    var world = feverWorld()
    _ = world.tick()
    let house = merchantHouse(in: &world)
    let physician = addOperational(.physician, at: TileCoordinate(x: 33, y: 30), in: &world)
    let events = runTended(&world, house: house, untilTick: firstTick(of: .autumn, 1201) + CalendarState.ticksPerSeason)
    #expect(!events.contains(.residentLeftWithFever(house: house)))
    #expect(world.buildings[physician]?.fuelled == true)
    #expect(world.snapshot().feverHouses.isEmpty)
}

@Test("scenario: a fever house can't advance")
func feverHouseCannotAdvance() throws {
    var world = feverWorld()
    _ = world.tick()
    let house = merchantHouse(in: &world)
    world.populations[house]?.tier = .citizens
    world.populations[house]?.population = 6
    _ = runTended(&world, house: house, untilTick: firstTick(of: .autumn, 1201) + 1)
    let building = try #require(world.buildings[house])
    #expect(world.isHeldBackByFever(building))
    #expect(world.snapshot().feverHouses.contains(house))
}

@Test("scenario: Physician idle in a quiet year")
func physicianIdleInAQuietYear() {
    var world = eventsWorld(size: 12)
    let physician = addOperational(.physician, at: TileCoordinate(x: 0, y: 0), in: &world)
    world.stockpiles[physician]?.deposit(.herbs, amount: 4)
    _ = runEvents(&world, untilTick: 400)
    #expect(world.stockpiles[physician]?.quantity(of: .herbs) == 4)
}

@Test("scenario: Physician burns during a warning")
func physicianBurnsDuringAWarning() {
    var world = eventsWorld(size: 12)
    let physician = addOperational(.physician, at: TileCoordinate(x: 0, y: 0), in: &world)
    world.stockpiles[physician]?.deposit(.herbs, amount: 4)
    world.seasonalEvents.warned = SeasonalEventOnset(event: .fever, season: .autumn)
    _ = runEvents(&world, untilTick: 100)
    #expect(world.stockpiles[physician]?.quantity(of: .herbs) == 3)
    #expect(world.buildings[physician]?.fuelled == true)
}

@Test("scenario: Buying herbs")
func buyingHerbs() {
    #expect(Good.herbs.marketTerms == MarketTerms(buyLimit: 10, sellLimit: 20))
    #expect(Good.herbs.basePrice == 5)
    #expect(HouseTier.allCases.allSatisfy { !$0.needs.contains(.herbs) })
    #expect(!BuildingKind.herbGarden.isCrop)
    #expect(ProductionCatalog.recipe(for: .herbGarden)?.cycleTicks == 60)
}

@Test("scenario: fever leaves the decline grace alone")
func feverLeavesTheGraceAlone() {
    var world = feverWorld()
    _ = world.tick()
    let house = merchantHouse(in: &world)
    _ = runTended(&world, house: house, untilTick: firstTick(of: .autumn, 1201) + 200)
    // A resident left, and the stocked house has no short run to show for it.
    let short = Good.allCases.filter { (world.populations[house]?.shortIntervals(of: $0) ?? 0) > 0 }
    #expect(world.seasonalEvents.fever?.residentsLeft == 1)
    #expect(short.isEmpty)
}

@Test("scenario: the fever's district shows its houses as threatened")
func feverDistrictShowsItsHouses() throws {
    var world = feverWorld()
    _ = world.tick()
    let area = try #require(world.threatenedArea())
    let threatened = Set(area.targets.compactMap { world.occupiedTiles[$0] })
    #expect(!threatened.isEmpty)
    #expect(threatened.allSatisfy { world.buildings[$0]?.kind == .house })
    #expect(World.isFlammable(.physician) && World.isFlammable(.herbGarden))
}

@Test("scenario: an idle physician books no herbs burned")
func idlePhysicianBooksNoHerbs() {
    var world = eventsWorld(size: 12)
    let physician = addOperational(.physician, at: TileCoordinate(x: 0, y: 0), in: &world)
    world.stockpiles[physician]?.deposit(.herbs, amount: 4)
    world.buildings[physician]?.fuelled = true
    _ = runEvents(&world, untilTick: 400)
    let used = world.statistics.current.goods[.herbs]?.usedByProduction ?? 0
    #expect(used == 0)
}
