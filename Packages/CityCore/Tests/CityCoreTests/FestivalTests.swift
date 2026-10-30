import Foundation
import Testing
@testable import CityCore

// Scenarios from openspec/changes/add-event-counterplay (seasonal-events /
// The town asks for a festival; orders / The town issues festival orders;
// population-and-needs / Festivals speed advancement near the market).

private let season = CalendarState.ticksPerSeason
/// Spring 1201: the season a scheduled festival is requested in.
private let requestSeason = 4

/// The orders fixture with a marketplace on its road, seasonal events on
/// and a festival scheduled for spring 1201.
private func festivalFixture(difficulty: Difficulty = .normal) -> OrdersFixture {
    var fixture = OrdersFixture(difficulty: difficulty)
    fixture.world.testPlace(.marketplace, at: TileCoordinate(x: fixture.warehouseRoad.x + 1, y: 20), owner: .player)
    fixture.world.seasonalEvents.enabled = true
    fixture.world.seasonalEvents.schedule = [ScheduledSeasonalEvent(year: 1201, event: .festival, onset: .spring)]
    return fixture
}

/// Crosses into spring 1201 with `output` as each of the last four seasons'.
@discardableResult
private func request(_ fixture: inout OrdersFixture, output: [Good: Int] = [.bread: 20, .beer: 12]) -> [WorldEvent] {
    fixture.cross(season: requestSeason, output: output)
}

private func townOrders(_ fixture: OrdersFixture) -> [Order] {
    fixture.orders.filter { $0.issuer == .town }
}

/// Fills every town order as if its shipments had arrived.
private func deliver(_ goods: Set<Good>, in fixture: inout OrdersFixture) {
    for index in fixture.world.orders.orders.indices {
        let order = fixture.world.orders.orders[index]
        if order.issuer == .town, goods.contains(order.good) {
            fixture.world.orders.orders[index].state = .accepted
            fixture.world.orders.orders[index].delivered = order.quantity
        }
    }
}

// MARK: - The request

@Test("scenario: the town asks for bread and its luxury at the start of the festival's season")
func festivalRequestIssuesTwoTownOrders() {
    var fixture = festivalFixture()
    let events = request(&fixture)
    let orders = townOrders(fixture)
    #expect(orders.map(\.good) == [.bread, .beer])
    #expect(orders.map(\.quantity) == [10, 6])
    let deadline = UInt64(requestSeason + 1) * season - 1
    #expect(orders.allSatisfy { $0.deadlineTick == deadline && $0.state == .offered && $0.reward == 0 })
    #expect(events.contains(.seasonalEventWarned(event: .festival, onset: .spring)))
    #expect(fixture.world.seasonalEvents.festival?.orders == orders.map(\.id))
}

@Test("scenario: an Easy festival gives two seasons")
func easyFestivalWindow() {
    var fixture = festivalFixture(difficulty: .easy)
    request(&fixture)
    let deadlines = townOrders(fixture).map(\.deadlineTick)
    #expect(deadlines == [UInt64(requestSeason + 2) * season - 1, UInt64(requestSeason + 2) * season - 1])
    let named = fixture.world.currentSeasonalEvent
    #expect(named == SeasonalEventOnset(event: .festival, season: .summer))
}

@Test("scenario: festival orders are clamped to their bounds")
func festivalOrdersAreClamped() {
    var fixture = festivalFixture()
    request(&fixture, output: [.bread: 100, .beer: 2])
    #expect(townOrders(fixture).map(\.quantity) == [30, 4])
}

@Test("scenario: a town that made no luxury gets no festival")
func noLuxuryNoFestival() {
    var fixture = festivalFixture()
    let events = request(&fixture, output: [.bread: 20])
    #expect(townOrders(fixture).isEmpty)
    #expect(events.seasonalEvents.isEmpty)
}

@Test("scenario: a town without a town center gets no festival")
func noTownCenterNoFestival() {
    var fixture = festivalFixture()
    fixture.world.buildings.removeValue(forKey: fixture.center)
    let events = request(&fixture)
    #expect(townOrders(fixture).isEmpty)
    #expect(events.seasonalEvents.isEmpty)
}

// MARK: - Outside the board's limits

@Test("scenario: A festival beside two crown orders")
func festivalBesideTwoCrownOrders() {
    var fixture = festivalFixture()
    request(&fixture)
    fixture.world.testAddOrder(state: .accepted)
    fixture.world.testAddOrder(state: .accepted)
    for order in townOrders(fixture) {
        fixture.world.enqueue(.acceptOrder(order.id))
    }
    fixture.run(to: fixture.world.tickCount + 1)
    let states = townOrders(fixture).map(\.state)
    #expect(states == [.accepted, .accepted])
    #expect(fixture.world.acceptedOrderCount == 2)
}

@Test("scenario: A missed festival costs no favour")
func missedFestivalCostsNoFavour() {
    var fixture = festivalFixture()
    fixture.world.orders.favour.adjust(.crown, by: 4)
    request(&fixture)
    for order in townOrders(fixture) {
        fixture.world.enqueue(.acceptOrder(order.id))
    }
    var control = festivalFixture()
    request(&control)
    let end = UInt64(requestSeason + 1) * season + 2
    control.run(to: end)
    let events = fixture.run(to: end)
    #expect(fixture.world.orders.favour.crown == 4)
    #expect(fixture.world.orders.favour.value(for: .town) == 0)
    #expect(fixture.world.orders.failedCount == 0)
    #expect(townOrders(fixture).allSatisfy { !$0.state.isOpen })
    #expect(events.contains(.seasonalEventEnded(event: .festival, toll: SeasonalEventToll(count: 0))))
    #expect(fixture.world.seasonalEvents.festival == nil)
    #expect(fixture.world.seasonalEvents.festivalUntil == nil)
    #expect(fixture.world.economy.balance == control.world.economy.balance)
}

@Test("scenario: Half a festival is no festival")
func halfAFestivalIsNoFestival() {
    var fixture = festivalFixture()
    request(&fixture)
    deliver([.bread], in: &fixture)
    let events = fixture.run(to: UInt64(requestSeason + 1) * season + 2)
    #expect(!events.contains(.seasonalEventStarted(event: .festival)))
    #expect(events.contains(.seasonalEventEnded(event: .festival, toll: SeasonalEventToll(count: 0))))
    #expect(fixture.world.seasonalEvents.festivalUntil == nil)
}

@Test("scenario: declining a festival order calls the festival off")
func decliningCallsTheFestivalOff() throws {
    var fixture = festivalFixture()
    request(&fixture)
    let luxury = try #require(townOrders(fixture).last)
    fixture.world.enqueue(.declineOrder(luxury.id))
    let events = fixture.run(to: fixture.world.tickCount + 2)
    #expect(events.contains(.seasonalEventEnded(event: .festival, toll: SeasonalEventToll(count: 0))))
    #expect(townOrders(fixture).allSatisfy { !$0.state.isOpen })
    #expect(fixture.world.seasonalEvents.active == nil)
}

// MARK: - The reward

@Test("scenario: both orders filled hold the festival for four seasons")
func bothOrdersHoldTheFestival() {
    var fixture = festivalFixture()
    request(&fixture)
    let fulfilled = fixture.world.orders.fulfilledCount
    deliver([.bread, .beer], in: &fixture)
    let events = fixture.run(to: fixture.world.tickCount + 2)
    #expect(events.contains(.seasonalEventStarted(event: .festival)))
    #expect(fixture.world.seasonalEvents.festivalUntil == UInt64(requestSeason + 4) * season - 1)
    #expect(fixture.world.isFestivalRunning)
    #expect(fixture.world.snapshot().isFestivalCrowd)
    #expect(fixture.world.seasonalEvents.active == nil)
    #expect(fixture.world.orders.fulfilledCount == fulfilled)
}

@Test("scenario: trimming the board's history never calls a festival off")
func trimmingKeepsTheFestival() {
    var fixture = festivalFixture()
    request(&fixture)
    deliver([.bread, .beer], in: &fixture)
    for _ in 0 ..< OrderRules.closedOrdersKept + 2 {
        fixture.world.testAddOrder(state: .expired)
    }
    let events = fixture.run(to: fixture.world.tickCount + 2)
    #expect(events.contains(.seasonalEventStarted(event: .festival)))
    #expect(!events.contains(.seasonalEventEnded(event: .festival, toll: SeasonalEventToll(count: 0))))
}

@Test("scenario: the crowd leaves after the festival's first season")
func festivalCrowdLeaves() {
    var fixture = festivalFixture()
    fixture.world.seasonalEvents.festivalUntil = 4 * season - 1
    fixture.run(to: season - 1)
    let first = fixture.world.snapshot().isFestivalCrowd
    fixture.run(to: season)
    let second = fixture.world.snapshot().isFestivalCrowd
    #expect(first)
    #expect(!second)
    #expect(fixture.world.isFestivalRunning)
}

@Test("scenario: the festival ends after its four seasons")
func festivalEnds() {
    var fixture = festivalFixture()
    fixture.world.seasonalEvents.festivalUntil = 10
    fixture.run(to: 12)
    #expect(!fixture.world.isFestivalRunning)
    #expect(fixture.world.seasonalEvents.festivalUntil == nil)
}

@Test("scenario: A festival reward does not block the next year")
func festivalDoesNotBlockTheNextYear() {
    var world = eventsWorld(size: 12)
    world.seasonalEvents.schedule = [ScheduledSeasonalEvent(year: 1201, event: .fever, onset: .autumn)]
    world.seasonalEvents.festivalUntil = firstTick(of: .summer, 1201)
    _ = runSeasons(&world, untilTick: firstTick(of: .spring, 1201) + 1)
    #expect(world.seasonalEvents.plan?.onset == SeasonalEventOnset(event: .fever, season: .autumn))
}

// MARK: - Near the market

/// A road along y = 3 with a marketplace at (0, 1) and a merchant house of
/// 8 at (6, 4) beside it.
private func marketStreet() -> (world: World, house: EntityID) {
    var world = World.fixtureWithTerrain(width: 44, height: 9, fill: .grass, seed: 1)
    for x in 0 ... 43 {
        let tile = TileCoordinate(x: x, y: 3)
        SignatureFixture.inject(.road, at: tile, in: &world)
        world.roadGraph.addRoad(at: tile)
    }
    addOperational(.marketplace, at: TileCoordinate(x: 0, y: 1), in: &world)
    let house = addOperational(.house, at: TileCoordinate(x: 6, y: 4), residents: 8, in: &world)
    world.populations[house]?.tier = .merchants
    return (world, house)
}

@Test("scenario: A festival pays more tax")
func festivalPaysMoreTax() {
    var (world, _) = marketStreet()
    let plain = world.playerTaxAndUpkeep.tax
    world.seasonalEvents.festivalUntil = 1000
    let festive = world.playerTaxAndUpkeep.tax
    #expect(plain == 32)
    #expect(festive == 35)
}

@Test("scenario: a house out of the market's reach pays the plain tax")
func farHousePaysPlainTax() {
    var (world, house) = marketStreet()
    world.buildings.removeValue(forKey: house)
    world.populations.removeValue(forKey: house)
    let far = addOperational(.house, at: TileCoordinate(x: 40, y: 4), residents: 8, in: &world)
    world.populations[far]?.tier = .merchants
    world.seasonalEvents.festivalUntil = 1000
    let tax = world.playerTaxAndUpkeep.tax
    #expect(tax == 32)
}

@Test("scenario: Festival house advances sooner")
func festivalHouseAdvancesSooner() {
    func peasants(festival: Bool) -> HouseTier? {
        var (world, house) = marketStreet()
        world.populations[house]?.tier = .peasants
        world.populations[house]?.population = 4
        _ = world.populations[house]?.addStock(.food, amount: 4)
        if let market = world.buildings.values.first(where: { $0.kind == .marketplace }) {
            world.stockpiles[market.id]?.deposit(.food, amount: 40)
            world.stockpiles[market.id]?.deposit(.planks, amount: 40)
        }
        if festival {
            world.seasonalEvents.festivalUntil = 1000
        }
        for _ in 0 ..< 70 {
            _ = world.tick()
        }
        return world.populations[house]?.tier
    }
    let festive = peasants(festival: true)
    let plain = peasants(festival: false)
    #expect(festive == .citizens)
    #expect(plain == .peasants)
}

@Test("scenario: festival orders survive a save and load")
func festivalOrdersRoundTrip() throws {
    var fixture = festivalFixture()
    request(&fixture)
    let data = try JSONEncoder().encode(fixture.world)
    let loaded = try JSONDecoder().decode(World.self, from: data)
    let issuers = loaded.orders.orders.filter { $0.issuer == .town }.map(\.good)
    #expect(issuers == [.bread, .beer])
    #expect(loaded.seasonalEvents.festival == fixture.world.seasonalEvents.festival)
    let encoded = try String(bytes: JSONEncoder().encode(OrderIssuer.town), encoding: .utf8)
    #expect(encoded == "\"town\"")
}
