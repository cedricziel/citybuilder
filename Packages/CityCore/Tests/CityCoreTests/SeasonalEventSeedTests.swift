import Testing
@testable import CityCore

// The test helper behind the `-uiTestSeedBlight`, `-uiTestSeedFever` and
// `-uiTestSeedFestival` launch flags: it plans an event for the next
// season change that can announce it.

@Test("a seeded hazard is warned at the next season change that leads into one of its seasons", arguments: [
    SeasonalEvent.fire, .blight, .fever
])
func seededHazardIsWarned(event: SeasonalEvent) {
    var world = eventsWorld(seed: 4)
    world.seasonalEvents.enabled = false
    addHouses(6, in: &world)
    addOperational(.farm, at: TileCoordinate(x: 0, y: 4), in: &world)
    let change = world.seedSeasonalEvent(event)
    #expect(world.seasonalEvents.enabled)
    #expect(change == firstTick(of: .summer, 1200))
    let events = runSeasons(&world, untilTick: change)
    #expect(events.contains(.seasonalEventWarned(event: event, onset: .autumn)))
}

@Test("a seeded festival is asked for in its next season, after the season with its goods made has closed")
func seededFestivalIsRequested() {
    var fixture = OrdersFixture()
    fixture.world.testPlace(.marketplace, at: TileCoordinate(x: fixture.warehouseRoad.x + 1, y: 20), owner: .player)
    let change = fixture.world.seedSeasonalEvent(.festival)
    #expect(change == firstTick(of: .spring, 1201))
    let events = runSeasons(&fixture.world, untilTick: change)
    #expect(events.contains(.seasonalEventWarned(event: .festival, onset: .spring)))
    #expect(fixture.orders.filter { $0.issuer == .town }.map(\.good) == [.bread, .beer])
}
