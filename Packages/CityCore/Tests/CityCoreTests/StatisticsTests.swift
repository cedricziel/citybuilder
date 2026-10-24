import Foundation
import Testing
@testable import CityCore

// Scenarios from openspec/changes/add-statistics-screen (statistics,
// persistence-save-load).

private let season = Int(CalendarState.ticksPerSeason)

private func grassWorld() -> World {
    var world = World.fixtureWithTerrain(width: 24, height: 12, fill: .grass, seed: 5)
    world.testMaterialCredits = [:]
    return world
}

/// Feeds `events` through the recorder as if a tick had produced them.
private func record(_ events: [WorldEvent], in world: inout World) {
    world.runStatisticsSystem(events: events)
}

/// Runs to the last tick before a boundary, applies `setup`, then ticks
/// over the boundary and returns the season that closed. The setup lands
/// one tick before the close so that only a single tick acts on it.
private func closedSeason(_ world: inout World, after setup: (inout World) -> Void = { _ in }) -> SeasonStatistics {
    while !(world.tickCount + 1).isMultiple(of: CalendarState.ticksPerSeason) {
        world.tick()
    }
    setup(&world)
    world.tick()
    return world.statistics.seasons[world.statistics.seasons.count - 1]
}

// MARK: - The ring

@Test("scenario: a season closes at the boundary")
func scenarioASeasonClosesAtTheBoundary() {
    var world = grassWorld()
    for _ in 0 ..< season - 1 {
        world.tick()
    }
    #expect(world.statistics.seasons.isEmpty)
    world.tick()
    #expect(world.statistics.seasons.count == 1)
    #expect(world.statistics.seasons[0].season == 0)
    #expect(world.statistics.current == SeasonStatistics())
}

@Test("scenario: the ring is bounded")
func scenarioTheRingIsBounded() {
    var history = StatisticsHistory()
    for number in 0 ..< 45 {
        var record = history.current
        record.season = number
        history.close(record)
    }
    #expect(history.seasons.count == StatisticsHistory.capacity)
    #expect(history.seasons.first?.season == 5)
    #expect(history.seasons.last?.season == 44)
}

@Test("scenario: empty entries are left out")
func scenarioEmptyEntriesAreLeftOut() {
    var world = grassWorld()
    record([.marketTraded(good: .tools, quantity: 0, total: 0, direction: .sold)], in: &world)
    #expect(world.statistics.current.goods[.tools] != nil)
    #expect(closedSeason(&world).goods[.tools] == nil)
}

@Test("scenario: the history is deterministic")
func scenarioTheHistoryIsDeterministic() throws {
    var first = World.newGame(layout: .singleIsland, seed: 11)
    var second = first
    _ = first.testRun(ticks: season + 300)
    _ = second.testRun(ticks: season + 100)
    var reloaded = try JSONDecoder().decode(World.self, from: JSONEncoder().encode(second))
    #expect(reloaded.statistics == second.statistics)
    _ = reloaded.testRun(ticks: 200)
    #expect(reloaded == first)
    #expect(first.statistics.seasons.count == 1)
}

// MARK: - Saves

@Test("scenario: a save without a history loads")
func scenarioASaveWithoutAHistoryLoads() throws {
    var world = grassWorld()
    _ = world.testRun(ticks: 3)
    var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(world)) as? [String: Any])
    #expect(object.removeValue(forKey: "statistics") != nil)
    let old = try JSONSerialization.data(withJSONObject: object)
    let loaded = try JSONDecoder().decode(World.self, from: old)
    #expect(loaded.statistics == StatisticsHistory())
    #expect(loaded == world)
}

@Test("scenario: a history survives save and load")
func scenarioAHistorySurvivesSaveAndLoad() throws {
    var world = grassWorld()
    record([.taxesCollected(amount: 7)], in: &world)
    _ = world.testRun(ticks: season * 5 + 20)
    record([.upkeepPaid(amount: 3)], in: &world)
    #expect(world.statistics.seasons.count == 5)
    let loaded = try JSONDecoder().decode(World.self, from: JSONEncoder().encode(world))
    #expect(loaded.statistics == world.statistics)
    #expect(loaded.statistics.current.money.upkeep == 3)
}

@Test("scenario: the snapshot carries the history")
func scenarioTheSnapshotCarriesTheHistory() {
    var world = grassWorld()
    _ = world.testRun(ticks: season)
    #expect(world.snapshot().statistics == world.statistics)
    #expect(world.snapshot().statistics.seasons.count == 1)
}

// MARK: - Goods flows

@Test("scenario: made and used by production")
func scenarioMadeAndUsedByProduction() {
    var world = grassWorld()
    let sawmill = world.testPlace(.sawmill, at: TileCoordinate(x: 2, y: 2), owner: .player)
    world.stockpiles[sawmill] = Stockpile(capacity: 16)
    world.stockpiles[sawmill]?.deposit(.wood, amount: 1)
    _ = world.testRun(ticks: 40)
    let goods = world.statistics.current.goods
    #expect(goods[.planks]?.made == 1)
    #expect(goods[.wood]?.usedByProduction == 1)
    #expect(goods[.wood]?.used == 1)
}

@Test("scenario: a rival's cycle is not recorded")
func scenarioARivalsCycleIsNotRecorded() {
    var world = grassWorld()
    let sawmill = world.testPlace(.sawmill, at: TileCoordinate(x: 2, y: 2), owner: .rival(1))
    record([.productionCycleCompleted(producer: sawmill, kind: .sawmill)], in: &world)
    #expect(world.statistics.current.goods.isEmpty)
}

@Test("a completed monument has no recipe to record")
func aCompletedMonumentHasNoRecipeToRecord() {
    var world = grassWorld()
    let monument = world.testPlace(.monument, at: TileCoordinate(x: 2, y: 2), owner: .player)
    world.buildings[monument]?.projectStages = World.monumentStages
    record([.productionCycleCompleted(producer: monument, kind: .monument)], in: &world)
    #expect(world.statistics.current.goods.isEmpty)
}

@Test("scenario: houses count what they drew")
func scenarioHousesCountWhatTheyDrew() {
    var world = grassWorld()
    let center = world.testPlace(.townCenter, at: TileCoordinate(x: 6, y: 0), owner: .player)
    let house = world.testPlace(.house, at: TileCoordinate(x: 1, y: 1), owner: .player)
    for x in 0 ... 10 {
        world.testPlace(.road, at: TileCoordinate(x: x, y: 3), owner: .player)
        world.roadGraph.addRoad(at: TileCoordinate(x: x, y: 3))
    }
    var pop = HousePopulation()
    pop.tier = .merchants
    pop.population = 8
    world.populations[house] = pop
    var stock = Stockpile(capacity: 40)
    stock.deposit(.food, amount: 10)
    stock.deposit(.planks, amount: 10)
    stock.deposit(.tools, amount: 10)
    stock.deposit(.bread, amount: 1)
    world.stockpiles[center] = stock
    let interval = Int(HousePopulation.consumptionIntervalTicks)
    _ = world.testRun(ticks: interval)
    let goods = world.statistics.current.goods
    #expect(goods[.bread]?.usedByHouses == 1)
    #expect(goods[.food]?.usedByHouses == 4)
    #expect(world.populations[house]?.isShort(.bread) == true)
}

@Test("a rival's house is not recorded and a drawn zero is not either")
func aRivalsHouseIsNotRecorded() throws {
    var world = grassWorld()
    let rivalHouse = world.testAddBuilding(.house, owner: .rival(1))
    let playerHouse = world.testAddBuilding(.house, owner: .player)
    try world.recordHouseUse(of: .food, drawn: 5, by: #require(world.buildings[rivalHouse]))
    try world.recordHouseUse(of: .food, drawn: 0, by: #require(world.buildings[playerHouse]))
    #expect(world.statistics.current.goods.isEmpty)
}

@Test("scenario: construction counts when the building completes")
func scenarioConstructionCountsWhenTheBuildingCompletes() throws {
    var world = grassWorld()
    let kind = try #require(BuildingKind.allCases.first { !BuildingCatalog.spec(for: $0).materialCost.isEmpty })
    let cost = BuildingCatalog.spec(for: kind).materialCost
    let mine = world.testPlace(kind, at: TileCoordinate(x: 2, y: 2), owner: .player)
    let theirs = world.testPlace(kind, at: TileCoordinate(x: 12, y: 2), owner: .rival(1))
    record([.constructionCompleted(building: theirs, kind: kind, anchor: TileCoordinate(x: 12, y: 2))], in: &world)
    #expect(world.statistics.current.goods.isEmpty)
    record([.constructionCompleted(building: mine, kind: kind, anchor: TileCoordinate(x: 2, y: 2))], in: &world)
    for (good, amount) in cost {
        #expect(world.statistics.current.goods[good]?.usedByConstruction == amount)
    }
}

@Test("scenario: trade")
func scenarioTrade() {
    var world = grassWorld()
    record([
        .marketTraded(good: .wood, quantity: 5, total: 10, direction: .sold),
        .tradeCompleted(rival: 1, good: .food, quantity: 2, total: 9, direction: .bought)
    ], in: &world)
    let current = world.statistics.current
    #expect(current.goods[.wood]?.sold == 5)
    #expect(current.goods[.food]?.bought == 2)
    #expect(current.money.tradeIncome == 10)
    #expect(current.money.tradeSpending == 9)
}

@Test("a real market sale is recorded")
func aRealMarketSaleIsRecorded() {
    var world = grassWorld()
    let center = world.testPlace(.townCenter, at: TileCoordinate(x: 2, y: 2), owner: .player)
    world.stockpiles[center]?.deposit(.wood, amount: 8)
    world.enqueue(.marketSell(center, .wood, 5))
    world.tick()
    #expect(world.statistics.current.goods[.wood]?.sold == 5)
    #expect(world.statistics.current.money.tradeIncome == 5 * Good.wood.marketPrice(.sold))
}

@Test("caravans count as sales, a rival's do not")
func caravansCountAsSales() {
    var world = grassWorld()
    let mine = world.testAddBuilding(.caravanserai, owner: .player)
    let theirs = world.testAddBuilding(.caravanserai, owner: .rival(1))
    record([.caravanSold(building: theirs, goods: [.tea: 9], revenue: 90)], in: &world)
    #expect(world.statistics.current.goods.isEmpty)
    record([.caravanSold(building: mine, goods: [.tea: 3, .wine: 1], revenue: 60)], in: &world)
    #expect(world.statistics.current.goods[.tea]?.sold == 3)
    #expect(world.statistics.current.goods[.wine]?.sold == 1)
    #expect(world.statistics.current.money.tradeIncome == 60)
}

@Test("scenario: tax and upkeep")
func scenarioTaxAndUpkeep() {
    var world = grassWorld()
    record([.taxesCollected(amount: 8), .taxesCollected(amount: 4), .upkeepPaid(amount: 5), .gameOver], in: &world)
    #expect(world.statistics.current.money.tax == 12)
    #expect(world.statistics.current.money.upkeep == 5)
}

@Test("fuel burned counts as used by production")
func fuelBurnedCountsAsUsedByProduction() throws {
    var world = grassWorld()
    let kind = try #require(BuildingKind.allCases.first { $0.fuel != nil })
    let fuel = try #require(kind.fuel)
    let burner = world.testPlace(kind, at: TileCoordinate(x: 2, y: 2), owner: .player)
    world.stockpiles[burner] = Stockpile(capacity: 40)
    world.stockpiles[burner]?.deposit(fuel.good, amount: fuel.amount)
    _ = world.testRun(ticks: Int(fuel.intervalTicks))
    #expect(world.statistics.current.goods[fuel.good]?.usedByProduction == fuel.amount)
    _ = world.testRun(ticks: Int(fuel.intervalTicks))
    #expect(world.statistics.current.goods[fuel.good]?.usedByProduction == fuel.amount)
}

@Test("scenario: stock is read at the boundary")
func scenarioStockIsReadAtTheBoundary() {
    var world = grassWorld()
    let warehouse = world.testPlace(.warehouse, at: TileCoordinate(x: 2, y: 2), owner: .player)
    let farWarehouse = world.testPlace(.warehouse, at: TileCoordinate(x: 12, y: 2), owner: .rival(1))
    let building = world.testPlace(.warehouse, at: TileCoordinate(x: 6, y: 6), owner: .player)
    for id in [warehouse, farWarehouse, building] {
        world.stockpiles[id] = Stockpile(capacity: 200)
        world.stockpiles[id]?.deposit(.bread, amount: id == warehouse ? 80 : 30)
    }
    let closed = closedSeason(&world) { $0.buildings[building]?.state = .constructing }
    #expect(closed.goods[.bread]?.stored == 80)
}

// MARK: - Money, people, rivals

@Test("scenario: the balance is read at the boundary")
func scenarioTheBalanceIsReadAtTheBoundary() {
    var world = grassWorld()
    #expect(closedSeason(&world) { $0.economy.balance = 1234 }.money.balance == 1234)
}

@Test("scenario: residents per tier")
func scenarioResidentsPerTier() {
    var world = grassWorld()
    let closed = closedSeason(&world) {
        $0.testAddHouse(owner: .player, residents: 4, tier: .peasants)
        $0.testAddHouse(owner: .player, residents: 3, tier: .peasants)
        $0.testAddHouse(owner: .player, residents: 5, tier: .citizens)
        $0.testAddHouse(owner: .player, residents: 0, tier: .merchants)
        $0.testAddHouse(owner: .rival(1), residents: 4, tier: .peasants)
    }
    #expect(closed.residents[.peasants] == 7)
    #expect(closed.residents[.citizens] == 5)
    #expect(closed.residents[.merchants] == nil)
}

@Test("scenario: rivals")
func scenarioRivals() {
    var world = grassWorld()
    let closed = closedSeason(&world) {
        $0.testSeatRival()
        $0.setRival(1) { $0.treasury = 700 }
        $0.testAddHouse(owner: .rival(1), residents: 4)
    }
    // The rival's house paid tax on the closing tick.
    let treasury = world.rival(1)?.treasury ?? 0
    #expect(treasury >= 700)
    #expect(closed.rivals == [RivalStatistics(id: 1, residents: 4, age: world.age, treasury: treasury)])
}

// MARK: - Producer activity

private func bakery(in world: inout World, flour: Int, bread: Int) -> EntityID {
    let id = world.testPlace(.bakery, at: TileCoordinate(x: 2, y: 2), owner: .player)
    world.stockpiles[id] = Stockpile(capacity: 16)
    world.stockpiles[id]?.deposit(.flour, amount: flour)
    world.stockpiles[id]?.deposit(.bread, amount: bread)
    return id
}

@Test("scenario: a working producer")
func scenarioAWorkingProducer() {
    var world = grassWorld()
    world.testPlace(.farm, at: TileCoordinate(x: 2, y: 2), owner: .player)
    _ = world.testRun(ticks: 10)
    #expect(world.statistics.current.producers[.farm]?.working == 1)
    #expect(world.statistics.current.producers[.farm]?.total == 1)
}

@Test("scenario: waiting for input")
func scenarioWaitingForInput() {
    var world = grassWorld()
    _ = bakery(in: &world, flour: 0, bread: 0)
    _ = world.testRun(ticks: 10)
    #expect(world.statistics.current.producers[.bakery]?.waiting == 1)
}

@Test("scenario: output stuck")
func scenarioOutputStuck() {
    var world = grassWorld()
    _ = bakery(in: &world, flour: 1, bread: 15)
    _ = world.testRun(ticks: 10)
    #expect(world.statistics.current.producers[.bakery]?.stuck == 1)
    #expect(world.statistics.current.goods[.bread]?.stuckSamples == 1)
}

@Test("scenario: blocked for another reason")
func scenarioBlockedForAnotherReason() {
    var world = grassWorld()
    world.testPlace(.lumberjackHut, at: TileCoordinate(x: 2, y: 2), owner: .player)
    _ = world.testRun(ticks: 10)
    #expect(world.statistics.current.producers[.lumberjackHut]?.blocked == 1)
}

@Test("scenario: between samples nothing is recorded")
func scenarioBetweenSamplesNothingIsRecorded() {
    var world = grassWorld()
    _ = bakery(in: &world, flour: 1, bread: 15)
    _ = world.testRun(ticks: 9)
    #expect(world.statistics.current.producers.isEmpty)
}

@Test("a rival's producer is not sampled")
func aRivalsProducerIsNotSampled() {
    var world = grassWorld()
    world.testPlace(.farm, at: TileCoordinate(x: 2, y: 2), owner: .rival(1))
    _ = world.testRun(ticks: 10)
    #expect(world.statistics.current.producers.isEmpty)
}

@Test("the stuck good is the one the producer holds most of")
func theStuckGoodIsTheOneTheProducerHoldsMostOf() {
    var world = grassWorld()
    let id = bakery(in: &world, flour: 1, bread: 15)
    world.stockpiles[id] = Stockpile(capacity: 16)
    world.stockpiles[id]?.deposit(.flour, amount: 1)
    world.stockpiles[id]?.deposit(.bread, amount: 15)
    _ = world.testRun(ticks: 10)
    let flows = world.statistics.current.goods
    #expect(flows[.bread]?.stuckSamples == 1)
    #expect(flows[.flour]?.stuckSamples == nil)
}
