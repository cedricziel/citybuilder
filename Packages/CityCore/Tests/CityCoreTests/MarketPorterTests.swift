import Foundation
import Testing
@testable import CityCore

// Scenarios from openspec/changes/visible-distribution
// (population-and-needs / Town center supplies house needs, Houses consume
// food and planks, Market porters supply houses, Market hubs gate tier
// advancement, Saves from before market porters keep their houses
// supplied).

/// A grass strip with a road along y = 3 from `roadFrom` to `roadTo`. A
/// house at (x, 4) sits x road tiles from a town center at (0, 0).
private func strip(width: Int = 44, roadFrom: Int = 0, roadTo: Int = 43) -> World {
    var world = World.fixtureWithTerrain(width: width, height: 9, fill: .grass, seed: 1)
    for x in roadFrom ... roadTo {
        let tile = TileCoordinate(x: x, y: 3)
        SignatureFixture.inject(.road, at: tile, in: &world)
        world.roadGraph.addRoad(at: tile)
    }
    return world
}

private func house(at x: Int, y: Int = 4, residents: UInt32 = 4, tier: HouseTier = .peasants, in world: inout World) -> EntityID {
    let id = addOperational(.house, at: TileCoordinate(x: x, y: y), residents: residents, in: &world)
    world.populations[id]?.tier = tier
    return id
}

private func stock(_ id: EntityID, _ goods: [Good: Int], in world: inout World) {
    for (good, units) in goods.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
        world.populations[id]?.addStock(good, amount: units)
    }
}

private func fill(_ id: EntityID, _ goods: [Good: Int], in world: inout World) {
    for (good, units) in goods {
        world.stockpiles[id]?.deposit(good, amount: units)
    }
}

private func run(_ world: inout World, ticks: Int) {
    for _ in 0 ..< ticks {
        _ = world.tick()
    }
}

/// Ticks until the next consumption interval has passed.
private func runPastConsumption(_ world: inout World) {
    let interval = HousePopulation.consumptionIntervalTicks
    run(&world, ticks: Int(interval - world.tickCount % interval))
}

/// One tick that is a consumption, so nobody moves in or out first.
private func consumeOnce(_ world: inout World) {
    world.tickCount = HousePopulation.consumptionIntervalTicks - 1
    run(&world, ticks: 1)
}

private func center(in world: inout World) -> EntityID {
    addOperational(.townCenter, at: TileCoordinate(x: 0, y: 0), in: &world)
}

// MARK: - Town center supplies house needs

@Test("scenario: Town center food satisfies a connected house")
func townCenterFoodSatisfiesAConnectedHouse() throws {
    var world = strip()
    let hub = center(in: &world)
    fill(hub, [.food: 10], in: &world)
    let home = house(at: 10, in: &world)
    #expect(world.hubService().hubOf[home]?.hub == hub)
    run(&world, ticks: 15)
    let pop = try #require(world.populations[home])
    #expect(pop.stock(of: .food) == 4)
    #expect(pop.isSatisfied(.food))
}

@Test("scenario: Unconnected town center does not satisfy needs")
func unconnectedTownCenterDoesNotSatisfyNeeds() {
    var world = strip(roadFrom: 6)
    let hub = center(in: &world)
    fill(hub, [.food: 10], in: &world)
    let home = house(at: 10, in: &world)
    run(&world, ticks: 15)
    #expect(world.hubService().hubOf[home] == nil)
    #expect(world.populations[home]?.isSatisfied(.food) == false)
}

@Test("scenario: Separate road networks do not share goods")
func separateRoadNetworksDoNotShareGoods() {
    var world = strip(roadTo: 5)
    for x in 8 ... 14 {
        world.roadGraph.addRoad(at: TileCoordinate(x: x, y: 3))
    }
    let hub = center(in: &world)
    fill(hub, [.food: 10], in: &world)
    let home = house(at: 10, in: &world)
    run(&world, ticks: 15)
    #expect(world.hubService().hubOf[home] == nil)
    #expect(world.populations[home]?.isSatisfied(.food) == false)
}

@Test("scenario: A house beyond the radius is not served")
func houseBeyondTheRadiusIsNotServed() {
    var world = strip()
    let hub = center(in: &world)
    fill(hub, [.food: 10], in: &world)
    let home = house(at: 25, in: &world)
    run(&world, ticks: 5)
    #expect(world.hubService().hubOf[home] == nil)
    #expect(world.porters.isEmpty)
}

@Test("scenario: The nearest hub serves a house")
func nearestHubServesAHouse() {
    var world = strip()
    _ = center(in: &world)
    let home = house(at: 12, in: &world)
    let market = addOperational(.marketplace, at: TileCoordinate(x: 16, y: 1), in: &world)
    #expect(world.hubService().hubOf[home]?.hub == market)
    #expect(world.hubService().housesOf[market] == [home])
}

@Test func equallyNearHubsServeFromTheLowerID() {
    var world = strip()
    let first = addOperational(.marketplace, at: TileCoordinate(x: 6, y: 1), in: &world)
    _ = addOperational(.marketplace, at: TileCoordinate(x: 14, y: 1), in: &world)
    let home = house(at: 10, in: &world)
    #expect(world.hubService().hubOf[home]?.hub == first)
}

@Test("scenario: A warehouse does not feed a house")
func warehouseDoesNotFeedAHouse() {
    var world = strip()
    let store = addOperational(.warehouse, at: TileCoordinate(x: 4, y: 0), in: &world)
    fill(store, [.food: 10], in: &world)
    let home = house(at: 10, in: &world)
    runPastConsumption(&world)
    #expect(world.populations[home]?.isSatisfied(.food) == false)
    #expect(world.stockpiles[store]?.quantity(of: .food) == 10)
}

@Test("scenario: Stock covers the gap between deliveries")
func stockCoversTheGapBetweenDeliveries() {
    var world = strip()
    let home = house(at: 10, in: &world)
    stock(home, [.food: 2], in: &world)
    run(&world, ticks: 1)
    #expect(world.populations[home]?.isSatisfied(.food) == true)
}

@Test func anEmptyHouseWaitsForItsFirstDelivery() {
    var world = strip()
    let home = house(at: 10, residents: 0, in: &world)
    run(&world, ticks: 1)
    #expect(world.populations[home]?.isSatisfied(.food) == false)
    stock(home, [.food: 1], in: &world)
    run(&world, ticks: 1)
    #expect(world.populations[home]?.isSatisfied(.food) == true)
}

// MARK: - Houses consume food and planks

@Test("scenario: Populated house eats food on the consumption interval")
func populatedHouseEatsFromItsStock() {
    var world = strip()
    let home = house(at: 10, tier: .citizens, in: &world)
    stock(home, [.food: 4, .planks: 2], in: &world)
    consumeOnce(&world)
    #expect(world.populations[home]?.stock(of: .food) == 2)
    #expect(world.populations[home]?.stock(of: .planks) == 1)
}

@Test("scenario: Peasants consume no planks")
func peasantsConsumeNoPlanks() {
    var world = strip()
    let home = house(at: 10, in: &world)
    stock(home, [.food: 2, .planks: 2], in: &world)
    consumeOnce(&world)
    #expect(world.populations[home]?.stock(of: .food) == 0)
    #expect(world.populations[home]?.stock(of: .planks) == 2)
}

@Test("scenario: Merchants eat bread")
func merchantsEatBreadFromTheirStock() {
    var world = strip()
    let home = house(at: 10, residents: 8, tier: .merchants, in: &world)
    stock(home, [.food: 8, .planks: 2, .bread: 4], in: &world)
    consumeOnce(&world)
    #expect(world.populations[home]?.stock(of: .food) == 4)
    #expect(world.populations[home]?.stock(of: .planks) == 1)
    #expect(world.populations[home]?.stock(of: .bread) == 2)
}

@Test("scenario: Houses leave the stores alone")
func housesLeaveTheStoresAlone() {
    var world = strip()
    let store = addOperational(.warehouse, at: TileCoordinate(x: 4, y: 0), in: &world)
    fill(store, [.food: 10], in: &world)
    let home = house(at: 10, in: &world)
    stock(home, [.food: 2], in: &world)
    consumeOnce(&world)
    #expect(world.populations[home]?.stock(of: .food) == 0)
    #expect(world.stockpiles[store]?.quantity(of: .food) == 10)
}

@Test("scenario: Unmet consumption reports the need as unmet")
func unmetConsumptionReportsTheNeedAsUnmet() {
    var world = strip()
    let home = house(at: 10, in: &world)
    stock(home, [.food: 1], in: &world)
    consumeOnce(&world)
    #expect(world.populations[home]?.stock(of: .food) == 0)
    #expect(world.populations[home]?.isSatisfied(.food) == false)
}

@Test("scenario: Empty house consumes nothing")
func emptyHouseConsumesNothing() {
    var world = strip()
    let home = house(at: 10, residents: 0, in: &world)
    stock(home, [.food: 2], in: &world)
    consumeOnce(&world)
    #expect(world.populations[home]?.stock(of: .food) == 2)
}

@Test("scenario: House stock capacity follows consumption")
func houseStockCapacityFollowsConsumption() {
    var pop = HousePopulation()
    pop.tier = .merchants
    pop.population = 8
    #expect(pop.stockCapacity(of: .food) == 8)
    #expect(pop.stockCapacity(of: .planks) == 2)
    #expect(pop.stockCapacity(of: .bread) == 4)
    #expect(pop.addStock(.food, amount: 10) == 8)
}

// MARK: - Market porters supply houses

@Test("scenario: A hub sends a porter to a house short of food")
func hubSendsAPorterToAHouseShortOfFood() throws {
    var world = strip()
    let hub = center(in: &world)
    fill(hub, [.food: 10], in: &world)
    let home = house(at: 10, in: &world)
    run(&world, ticks: 1)
    let porter = try #require(world.porters.first)
    #expect(world.porters.count == 1)
    #expect(porter.house == home)
    #expect(porter.basket == [Porter.Load(good: .food, units: 4)])
    #expect(world.stockpiles[hub]?.quantity(of: .food) == 6)
}

@Test("scenario: Porters go to the house that needs them most")
func portersGoToTheHouseThatNeedsThemMost() {
    var world = strip()
    let hub = center(in: &world)
    fill(hub, [.food: 10], in: &world)
    let half = house(at: 6, in: &world)
    stock(half, [.food: 2], in: &world)
    let empty = house(at: 12, in: &world)
    run(&world, ticks: 1)
    #expect(world.porters.map(\.house) == [empty])
}

@Test func equalNeedGoesToTheNearerHouse() {
    var world = strip()
    let hub = center(in: &world)
    fill(hub, [.food: 10], in: &world)
    _ = house(at: 12, in: &world)
    let near = house(at: 6, in: &world)
    run(&world, ticks: 1)
    #expect(world.porters.map(\.house) == [near])
}

@Test("scenario: Porter count follows the houses served")
func porterCountFollowsTheHousesServed() {
    var world = strip()
    let hub = center(in: &world)
    fill(hub, [.food: 40], in: &world)
    for x in [3, 6, 9, 12, 15] {
        _ = house(at: x, in: &world)
    }
    for x in [4, 7, 10, 13] {
        _ = house(at: x, y: 1, in: &world)
    }
    #expect(world.hubService().housesOf[hub]?.count == 9)
    run(&world, ticks: 1)
    #expect(world.porters.count == 3)
}

@Test("scenario: A basket holds at most 10 units")
func basketHoldsOneConsumptionOfEachNeed() throws {
    var world = strip()
    let hub = center(in: &world)
    fill(hub, [.food: 20, .planks: 20, .bread: 20, .tools: 20], in: &world)
    _ = house(at: 10, residents: 8, tier: .merchants, in: &world)
    run(&world, ticks: 1)
    let basket = try #require(world.porters.first?.basket)
    #expect(basket.map(\.good) == [.food, .planks, .bread, .tools])
    // One consumption of each need, then the two units left top up food.
    #expect(basket.map(\.units) == [6, 1, 2, 1])
}

@Test func aBasketStopsAtItsLimit() throws {
    var world = strip()
    let hub = center(in: &world)
    fill(hub, [.food: 40], in: &world)
    let home = house(at: 10, residents: 8, tier: .merchants, in: &world)
    world.populations[home]?.population = 40
    run(&world, ticks: 1)
    let basket = try #require(world.porters.first?.basket)
    #expect(basket == [Porter.Load(good: .food, units: 10)])
}

@Test("scenario: Porters walk back empty")
func portersWalkBackEmpty() throws {
    var world = strip()
    let hub = center(in: &world)
    fill(hub, [.food: 10], in: &world)
    let home = house(at: 10, in: &world)
    run(&world, ticks: 1)
    let trip = try #require(world.porters.first).path.count
    run(&world, ticks: trip + 1)
    let porter = try #require(world.porters.first)
    #expect(porter.returning)
    #expect(porter.basket.isEmpty)
    #expect(world.populations[home]?.stock(of: .food) == 4)
    #expect(world.porters.count == 1)
    run(&world, ticks: trip)
    #expect(world.porters.isEmpty)
    #expect(world.stockpiles[hub]?.quantity(of: .food) == 6)
}

@Test("scenario: Leftovers go back to the hub")
func leftoversGoBackToTheHub() {
    var world = strip()
    let hub = center(in: &world)
    fill(hub, [.food: 2], in: &world)
    let home = house(at: 10, in: &world)
    run(&world, ticks: 1)
    stock(home, [.food: 3], in: &world)
    run(&world, ticks: 11)
    #expect(world.populations[home]?.stock(of: .food) == 4)
    #expect(world.porters.first?.basket == [Porter.Load(good: .food, units: 1)])
    run(&world, ticks: 11)
    #expect(world.porters.isEmpty)
    #expect(world.stockpiles[hub]?.quantity(of: .food) == 1)
}

@Test func aPorterWhoseHouseIsGoneBringsEverythingBack() {
    var world = strip()
    let hub = center(in: &world)
    fill(hub, [.food: 2], in: &world)
    let home = house(at: 10, in: &world)
    run(&world, ticks: 1)
    world.buildings[home] = nil
    run(&world, ticks: 22)
    #expect(world.porters.isEmpty)
    #expect(world.stockpiles[hub]?.quantity(of: .food) == 2)
}

@Test func portersSurviveASave() throws {
    var world = strip()
    let hub = center(in: &world)
    fill(hub, [.food: 10], in: &world)
    _ = house(at: 10, in: &world)
    run(&world, ticks: 3)
    let decoded = try JSONDecoder().decode(World.self, from: JSONEncoder().encode(world))
    #expect(decoded.porters == world.porters)
}

// MARK: - Market hubs gate tier advancement

@Test("scenario: A warehouse's tools do not make merchants")
func warehouseToolsDoNotMakeMerchants() {
    var world = strip()
    let hub = center(in: &world)
    for good in HouseTier.merchants.needs(in: world.culture) where good != .tools {
        fill(hub, [good: 40], in: &world)
    }
    let store = addOperational(.warehouse, at: TileCoordinate(x: 14, y: 0), in: &world)
    fill(store, [.tools: 10], in: &world)
    let home = house(at: 6, residents: 6, tier: .citizens, in: &world)
    stock(home, [.food: 6, .planks: 2], in: &world)
    run(&world, ticks: 130)
    #expect(world.populations[home]?.tier == .citizens)
}

@Test func aHubHoldingTheNextTiersGoodsLetsAHouseAdvance() {
    var world = strip()
    let hub = center(in: &world)
    fill(hub, [.food: 40, .planks: 40], in: &world)
    let home = house(at: 6, residents: 4, in: &world)
    stock(home, [.food: 4], in: &world)
    run(&world, ticks: 130)
    #expect(world.populations[home]?.tier == .citizens)
}

// MARK: - Saves from before market porters

@Test("scenario: Loading an older save seeds house stock")
func loadingAnOlderSaveSeedsHouseStock() throws {
    let legacy = Data(#"{"population":4,"tier":1,"satisfiedGoods":["food"],"shortGoods":[]}"#.utf8)
    let pop = try JSONDecoder().decode(HousePopulation.self, from: legacy)
    #expect(pop.stock(of: .food) == 2)
    #expect(pop.stock(of: .planks) == 0)
    let saved = try JSONDecoder().decode(HousePopulation.self, from: JSONEncoder().encode(pop))
    #expect(saved == pop)
}

@Test func anOlderSavesHousesAreNotShortAtTheFirstDraw() throws {
    var world = strip()
    let home = house(at: 10, in: &world)
    world.populations[home]?.setSatisfied(.food, true)
    var json = try #require(String(bytes: JSONEncoder().encode(world), encoding: .utf8))
    json = json.replacingOccurrences(of: #","stock":[]"#, with: "").replacingOccurrences(of: #""stock":[],"#, with: "")
    var loaded = try JSONDecoder().decode(World.self, from: Data(json.utf8))
    runPastConsumption(&loaded)
    #expect(loaded.populations[home]?.isShort(.food) == false)
}

@Test func theSnapshotCarriesPorters() {
    var world = strip()
    let hub = center(in: &world)
    fill(hub, [.food: 10], in: &world)
    _ = house(at: 10, in: &world)
    run(&world, ticks: 1)
    #expect(world.snapshot().porters == world.porters)
    #expect(world.snapshot().porters.count == 1)
}

@Test func aPorterStandsOnItsPathTile() throws {
    var world = strip()
    let hub = center(in: &world)
    fill(hub, [.food: 10], in: &world)
    _ = house(at: 10, in: &world)
    run(&world, ticks: 3)
    var porter = try #require(world.porters.first)
    #expect(porter.currentTile == porter.path[2])
    porter.pathIndex = porter.path.count
    #expect(porter.currentTile == nil)
}

@Test func leftoversAHubCannotTakeGoOnToAStore() {
    var world = strip()
    let hub = center(in: &world)
    fill(hub, [.food: 2], in: &world)
    let store = addOperational(.warehouse, at: TileCoordinate(x: 4, y: 0), in: &world)
    let home = house(at: 10, in: &world)
    run(&world, ticks: 1)
    stock(home, [.food: 4], in: &world)
    let trip = world.porters.first?.path.count ?? 0
    run(&world, ticks: 2 * trip - 1)
    world.buildings[hub] = nil
    world.stockpiles[hub] = nil
    run(&world, ticks: 1)
    #expect(world.porters.isEmpty)
    let onward = world.carriers.values.map(\.mission)
    #expect(onward.map(\.destination) == [store])
    #expect(onward.map(\.amount) == [2])
}

@Test func anOlderSavesEmptyHouseIsSeededForItsFirstResident() throws {
    let legacy = Data(#"{"population":0,"tier":1,"satisfiedGoods":["food"],"shortGoods":[]}"#.utf8)
    let pop = try JSONDecoder().decode(HousePopulation.self, from: legacy)
    #expect(pop.stock(of: .food) == 1)
}

@Test("scenario: Porters serve the higher tier first")
func portersServeTheHigherTierFirst() {
    var world = strip()
    let hub = center(in: &world)
    fill(hub, [.food: 10, .planks: 10], in: &world)
    _ = house(at: 6, in: &world)
    let citizens = house(at: 12, tier: .citizens, in: &world)
    stock(citizens, [.food: 3, .planks: 1], in: &world)
    run(&world, ticks: 1)
    #expect(world.porters.map(\.house) == [citizens])
}

@Test("scenario: A rival's porters go by stock ratio alone")
func aRivalsPortersGoByStockRatioAlone() {
    var world = strip()
    let hub = SignatureFixture.inject(.townCenter, at: TileCoordinate(x: 0, y: 0), in: &world, owner: .rival(1))
    fill(hub, [.food: 10, .planks: 10], in: &world)
    let peasants = SignatureFixture.inject(.house, at: TileCoordinate(x: 6, y: 4), in: &world, owner: .rival(1))
    var pop = HousePopulation()
    pop.population = 4
    world.populations[peasants] = pop
    let citizens = SignatureFixture.inject(.house, at: TileCoordinate(x: 12, y: 4), in: &world, owner: .rival(1))
    pop.tier = .citizens
    world.populations[citizens] = pop
    stock(citizens, [.food: 3, .planks: 1], in: &world)
    run(&world, ticks: 1)
    #expect(world.porters.map(\.house) == [peasants])
}
