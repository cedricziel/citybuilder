import Foundation
import Testing
@testable import CityCore

// Scenarios from openspec/changes/add-town-market (town-market, economy).

/// Two islands across a strait: the player's to the west (x 0…8) holds
/// the town center and a warehouse, the east one (x 12…17) a second
/// warehouse. Every buffer starts empty and the player has $1,000.
private struct MarketFixture {
    var world: World
    let townCenter: EntityID
    let warehouse: EntityID
    let farWarehouse: EntityID

    init(balance: Int64 = 1000) {
        var world = World.fixtureWithTerrain(width: 18, height: 6, fill: .water, seed: 3)
        world.testMaterialCredits = [:]
        for y in 0 ..< world.mapHeight {
            for x in Array(0 ... 8) + Array(12 ... 17) {
                world.terrainGrid[y * world.mapWidth + x] = .grass
            }
        }
        world.islands = IslandDetector.detectIslands(
            width: world.mapWidth, height: world.mapHeight, terrain: world.terrainGrid,
            mapHeightForClimate: world.mapHeight, seed: 3
        )
        townCenter = world.testPlace(.townCenter, at: TileCoordinate(x: 0, y: 0), owner: .player)
        warehouse = world.testPlace(.warehouse, at: TileCoordinate(x: 4, y: 0), owner: .player)
        farWarehouse = world.testPlace(.warehouse, at: TileCoordinate(x: 13, y: 0), owner: .player)
        world.economy.balance = balance
        self.world = world
    }

    /// Applies `command` at the next tick and returns that tick's events.
    @discardableResult
    mutating func run(_ command: Command) -> [WorldEvent] {
        world.enqueue(command)
        return world.tick().events
    }

    @discardableResult
    mutating func buy(_ good: Good, _ quantity: Int, at center: EntityID? = nil) -> [WorldEvent] {
        run(.marketBuy(center ?? townCenter, good, quantity))
    }

    @discardableResult
    mutating func sell(_ good: Good, _ quantity: Int, at center: EntityID? = nil) -> [WorldEvent] {
        run(.marketSell(center ?? townCenter, good, quantity))
    }

    func stock(_ good: Good, in buffer: EntityID? = nil) -> Int {
        world.stockpiles[buffer ?? townCenter]?.quantity(of: good) ?? 0
    }
}

private func trades(_ events: [WorldEvent]) -> [WorldEvent] {
    events.filter { if case .marketTraded = $0 { true } else { false } }
}

// MARK: - Market prices

@Test("scenario: Town market wood prices")
func townMarketWoodPrices() {
    #expect(Good.wood.marketPrice(.bought) == 6)
    #expect(Good.wood.marketPrice(.sold) == 2)
}

@Test("scenario: Grain sell price floor")
func grainSellPriceFloor() {
    #expect(Good.grain.marketPrice(.sold) == 1)
}

@Test("scenario: No trade loop makes money")
func noTradeLoopMakesMoney() {
    for good in Good.allCases {
        let buyPrices = [good.marketPrice(.bought), good.rivalPrice(.bought)]
        let sellPrices = [good.marketPrice(.sold), good.rivalPrice(.sold), good.basePrice]
        #expect(buyPrices.min() ?? 0 >= sellPrices.max() ?? .max, "\(good)")
    }
}

// MARK: - Buying

@Test("scenario: Buying wood at the town center")
func buyingWoodAtTheTownCenter() {
    var market = MarketFixture(balance: 500)
    market.buy(.wood, 4)
    #expect(market.stock(.wood) == 4)
    #expect(market.world.economy.balance == 476)
}

@Test("scenario: Seasonal buy limit")
func seasonalBuyLimit() {
    var market = MarketFixture()
    market.buy(.wood, 8)
    market.buy(.wood, 5)
    #expect(market.stock(.wood) == 10)
}

@Test("scenario: Full town center")
func fullTownCenter() {
    var market = MarketFixture()
    market.world.testSetStock([.planks: 37], in: market.townCenter)
    market.world.testSetStock([.planks: 200], in: market.warehouse)
    market.buy(.food, 10)
    #expect(market.stock(.food) == 3)
    #expect(market.stock(.food, in: market.farWarehouse) == 0)
}

@Test("scenario: A full town center buys into a warehouse")
func aFullTownCenterBuysIntoAWarehouse() {
    var market = MarketFixture()
    market.world.testSetStock([.planks: 40], in: market.townCenter)
    let events = market.buy(.food, 10)
    #expect(market.stock(.food, in: market.warehouse) == 10)
    #expect(trades(events) == [.marketTraded(good: .food, quantity: 10, total: 10 * Good.food.marketPrice(.bought), direction: .bought)])
}

@Test("scenario: The town center fills first")
func theTownCenterFillsFirst() {
    var market = MarketFixture()
    market.world.testSetStock([.planks: 37], in: market.townCenter)
    market.buy(.food, 10)
    #expect(market.stock(.food) == 3)
    #expect(market.stock(.food, in: market.warehouse) == 7)
}

@Test("scenario: Stores the town center's roads reach fill first")
func storesTheTownCentersRoadsReachFillFirst() {
    var market = MarketFixture()
    // A road under the town center (x 0…2, y 0…2) reaches a second
    // warehouse at (3, 3); the fixture's warehouse at (4, 0) touches no road.
    for x in 0 ... 2 {
        market.world.roadGraph.addRoad(at: TileCoordinate(x: x, y: 3))
    }
    let reached = market.world.testPlace(.warehouse, at: TileCoordinate(x: 3, y: 3), owner: .player)
    #expect(market.warehouse.raw < reached.raw)
    market.world.testSetStock([.planks: 40], in: market.townCenter)
    market.buy(.food, 10)
    #expect(market.stock(.food, in: reached) == 10)
    #expect(market.stock(.food, in: market.warehouse) == 0)
}

@Test("scenario: Warehouses fill before ports")
func warehousesFillBeforePorts() {
    var market = MarketFixture()
    // The fixture's warehouse is full; a port, then a second warehouse.
    market.world.testSetStock([.planks: 200], in: market.warehouse)
    let port = market.world.testPlace(.port, at: TileCoordinate(x: 7, y: 3), owner: .player)
    let warehouse = market.world.testPlace(.warehouse, at: TileCoordinate(x: 3, y: 3), owner: .player)
    #expect(port.raw < warehouse.raw)
    market.world.testSetStock([.planks: 40], in: market.townCenter)
    market.buy(.food, 10)
    #expect(market.stock(.food, in: warehouse) == 10)
    #expect(market.stock(.food, in: port) == 0)
}

@Test("scenario: Stores on another island stay out of a buy")
func storesOnAnotherIslandStayOutOfABuy() {
    var market = MarketFixture()
    market.world.testSetStock([.planks: 40], in: market.townCenter)
    market.world.testSetStock([.planks: 200], in: market.warehouse)
    let events = market.buy(.food, 10)
    #expect(market.stock(.food, in: market.farWarehouse) == 0)
    #expect(market.world.economy.balance == 1000)
    #expect(trades(events).isEmpty)
}

@Test("scenario: Short of money")
func shortOfMoney() {
    var market = MarketFixture(balance: 20)
    market.buy(.planks, 10)
    #expect(market.stock(.planks) == 1)
    #expect(market.world.economy.balance == 8)
}

@Test("scenario: Tools are not for sale")
func toolsAreNotForSale() {
    var market = MarketFixture()
    let before = market.world
    let events = market.buy(.tools, 1)
    #expect(market.world.stockpiles == before.stockpiles)
    #expect(market.world.economy == before.economy)
    #expect(market.world.market == before.market)
    #expect(trades(events).isEmpty)
}

@Test(arguments: [Owner.rival(1), .player])
func buyingNeedsAnOperationalPlayerTownCenter(owner: Owner) {
    var market = MarketFixture()
    let center = market.world.testPlace(.townCenter, at: TileCoordinate(x: 14, y: 3), owner: owner)
    if owner == .player { market.world.buildings[center]?.state = .constructing }
    let events = market.buy(.wood, 4, at: center)
    #expect(market.stock(.wood, in: center) == 0)
    #expect(market.world.economy.balance == 1000)
    #expect(trades(events).isEmpty)
}

@Test func buyingAtAWarehouseChangesNothing() {
    var market = MarketFixture()
    let events = market.buy(.wood, 4, at: market.warehouse)
    #expect(market.stock(.wood, in: market.warehouse) == 0)
    #expect(trades(events).isEmpty)
}

// MARK: - Selling

@Test("scenario: Selling tools at the town center")
func sellingToolsAtTheTownCenter() {
    var market = MarketFixture()
    market.world.testSetStock([.tools: 12], in: market.warehouse)
    market.sell(.tools, 5)
    #expect(market.stock(.tools, in: market.warehouse) == 7)
    #expect(market.world.economy.balance == 1075)
}

@Test("scenario: Seasonal sell limit")
func seasonalSellLimit() {
    var market = MarketFixture()
    market.world.testSetStock([.planks: 30], in: market.townCenter)
    market.sell(.planks, 18)
    market.sell(.planks, 10)
    #expect(market.stock(.planks) == 10)
}

@Test("scenario: Selling draws from every buffer on the island")
func sellingDrawsFromEveryBufferOnTheIsland() {
    var market = MarketFixture()
    market.world.testSetStock([.bread: 3], in: market.townCenter)
    market.world.testSetStock([.bread: 5], in: market.warehouse)
    market.sell(.bread, 6)
    #expect(market.townCenter.raw < market.warehouse.raw)
    #expect(market.stock(.bread) == 0)
    #expect(market.stock(.bread, in: market.warehouse) == 2)
}

@Test("scenario: Goods on another island are not sold")
func goodsOnAnotherIslandAreNotSold() {
    var market = MarketFixture()
    market.world.testSetStock([.bread: 5], in: market.farWarehouse)
    let events = market.sell(.bread, 5)
    #expect(market.stock(.bread, in: market.farWarehouse) == 5)
    #expect(market.world.economy.balance == 1000)
    #expect(trades(events).isEmpty)
}

@Test func sellingSkipsBuffersUnderConstruction() {
    var market = MarketFixture()
    market.world.testSetStock([.bread: 5], in: market.warehouse)
    market.world.buildings[market.warehouse]?.state = .constructing
    market.sell(.bread, 5)
    #expect(market.stock(.bread, in: market.warehouse) == 5)
}

// MARK: - Seasonal limits

@Test("scenario: New season resets the limits")
func newSeasonResetsTheLimits() {
    var market = MarketFixture()
    market.buy(.wood, 10)
    _ = market.world.testRun(ticks: Int(CalendarState.ticksPerSeason) - 2)
    #expect(market.world.tickCount == CalendarState.ticksPerSeason - 1)
    #expect(market.world.market.traded(.wood, .bought) == 10)
    market.world.tick()
    #expect(market.world.market == MarketLedger())
    market.buy(.wood, 10)
    #expect(market.stock(.wood) == 20)
}

@Test func tradeInTheSeasonChangeTickCountsForTheOldSeason() {
    var market = MarketFixture()
    _ = market.world.testRun(ticks: Int(CalendarState.ticksPerSeason) - 1)
    let events = market.buy(.wood, 10)
    #expect(market.world.tickCount == CalendarState.ticksPerSeason)
    #expect(trades(events) == [.marketTraded(good: .wood, quantity: 10, total: 60, direction: .bought)])
    #expect(market.world.market == MarketLedger())
    market.buy(.wood, 10)
    #expect(market.stock(.wood) == 20)
}

@Test(arguments: [0, -3])
func nonPositiveQuantityTradesNothing(quantity: Int) {
    var market = MarketFixture()
    market.world.testSetStock([.wood: 5], in: market.townCenter)
    let before = market.world
    let events = market.buy(.wood, quantity) + market.sell(.wood, quantity)
    #expect(market.world.stockpiles == before.stockpiles)
    #expect(market.world.economy == before.economy)
    #expect(market.world.market == before.market)
    #expect(trades(events).isEmpty)
}

@Test("scenario: Two town centers share the limit")
func twoTownCentersShareTheLimit() {
    var market = MarketFixture()
    let second = market.world.testPlace(.townCenter, at: TileCoordinate(x: 14, y: 3), owner: .player)
    market.buy(.wood, 10)
    market.buy(.wood, 5, at: second)
    #expect(market.stock(.wood, in: second) == 0)
}

@Test("scenario: Limits survive save and load")
func limitsSurviveSaveAndLoad() throws {
    var market = MarketFixture()
    market.buy(.food, 6)
    market.world = try JSONDecoder().decode(World.self, from: JSONEncoder().encode(market.world))
    market.buy(.food, 10)
    #expect(market.stock(.food) == 10)
}

@Test("scenario: Older saves start with fresh limits")
func olderSavesStartWithFreshLimits() throws {
    var market = MarketFixture()
    market.buy(.food, 6)
    var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(market.world)) as? [String: Any])
    #expect(json.removeValue(forKey: "market") != nil)
    let world = try JSONDecoder().decode(World.self, from: JSONSerialization.data(withJSONObject: json))
    #expect(world.market == MarketLedger())
    #expect(world.marketQuotes.allSatisfy { $0.buyLeft == $0.good.marketTerms.buyLimit })
    #expect(world.marketQuotes.allSatisfy { $0.sellLeft == $0.good.marketTerms.sellLimit })
}

// MARK: - Reporting

@Test("scenario: Town market trade event")
func townMarketTradeEvent() {
    var market = MarketFixture()
    let events = market.buy(.wood, 4)
    #expect(trades(events) == [.marketTraded(good: .wood, quantity: 4, total: 24, direction: .bought)])
}

@Test func tradeEventNamesNoBuilding() {
    let event = WorldEvent.marketTraded(good: .wood, quantity: 4, total: 24, direction: .bought)
    #expect(event.primaryEntityID == nil)
    #expect(event.buildingKind == nil)
}

@Test func saleEventCarriesTheSale() {
    var market = MarketFixture()
    market.world.testSetStock([.tools: 2], in: market.townCenter)
    let events = market.sell(.tools, 5)
    #expect(trades(events) == [.marketTraded(good: .tools, quantity: 2, total: 30, direction: .sold)])
}

@Test("scenario: Snapshot shows what is left")
func snapshotShowsWhatIsLeft() throws {
    var market = MarketFixture()
    market.world.testSetStock([.iron: 5], in: market.townCenter)
    market.sell(.iron, 5)
    let iron = try #require(market.world.snapshot().market.first { $0.good == .iron })
    #expect(iron.sellPrice == 7)
    #expect(iron.sellLeft == 15)
    #expect(iron.buyLeft == 0)
}

@Test func snapshotListsEveryTradedGoodInCatalogOrder() throws {
    let quotes = MarketFixture().world.snapshot().market
    #expect(quotes.map(\.good) == Good.allCases)
    let wood = try #require(quotes.first)
    #expect(wood == MarketQuote(good: .wood, buyPrice: 6, sellPrice: 2, buyLeft: 10, sellLeft: 20))
}

@Test("scenario: No trades after game over")
func noTradesAfterGameOver() {
    var market = MarketFixture()
    market.world.economy.gameOver = true
    let events = market.buy(.wood, 4)
    #expect(market.stock(.wood) == 0)
    #expect(market.world.economy.balance == 1000)
    #expect(trades(events).isEmpty)
}

// MARK: - Rivals

@Test("scenario: Market trade leaves rivals alone")
func marketTradeLeavesRivalsAlone() throws {
    var control = World.newGame(layout: .archipelago, seed: 0, difficulty: .normal)
    let center = try #require(control.goodsBuffers(of: .player).first { $0.kind == .townCenter }?.id)
    control.testSetStock([.wood: 20], in: center)
    var traded = control
    traded.enqueue(.marketSell(center, .wood, 20))
    let events = traded.tick().events
    control.tick()
    #expect(trades(events).count == 1)
    #expect(!traded.rivals.isEmpty)
    #expect(traded.rivals == control.rivals)
    for rival in traded.rivals {
        #expect(traded.rivalStock(rival.id) == control.rivalStock(rival.id))
        #expect(traded.sellOffers(of: rival.id) == control.sellOffers(of: rival.id))
        #expect(traded.buyOffers(of: rival.id) == control.buyOffers(of: rival.id))
    }
}

// MARK: - Economy

@Test("scenario: Market sale is not tax")
func marketSaleIsNotTax() {
    var market = MarketFixture()
    // Only the town center, which has no upkeep.
    market.world.buildings[market.warehouse] = nil
    market.world.buildings[market.farWarehouse] = nil
    market.world.testSetStock([.tools: 5], in: market.townCenter)
    _ = market.world.testRun(ticks: Int(Economy.taxIntervalTicks) - 1)
    let before = market.world.economy.balance
    let events = market.sell(.tools, 5)
    #expect(market.world.tickCount.isMultiple(of: Economy.taxIntervalTicks))
    #expect(market.world.economy.balance == before + 75)
    #expect(!events.contains { if case .taxesCollected = $0 { true } else { false } })
}

@Test("scenario: Buying never overdraws")
func buyingNeverOverdraws() {
    var market = MarketFixture(balance: 5)
    market.buy(.wood, 1)
    #expect(market.stock(.wood) == 0)
    #expect(market.world.economy.balance == 5)
}

@Test func buyingInDebtBuysNothing() {
    var market = MarketFixture(balance: -10)
    market.buy(.wood, 1)
    #expect(market.stock(.wood) == 0)
}

// MARK: - Reach

@Test func marketReachIsTheIslandSpaceAndStock() {
    var market = MarketFixture()
    market.world.testSetStock([.bread: 3, .wood: 4], in: market.townCenter)
    market.world.testSetStock([.bread: 5], in: market.warehouse)
    market.world.testSetStock([.iron: 9], in: market.farWarehouse)
    let reach = market.world.marketReach(at: market.townCenter)
    // 33 free in the town center and 195 in the warehouse beside it.
    #expect(reach == MarketReach(freeSpace: 228, stock: [.bread: 8, .wood: 4]))
}

@Test func marketReachLeavesOutBuffersUnderConstructionAndRivals() {
    var market = MarketFixture()
    let rivalWarehouse = market.world.testPlace(.warehouse, at: TileCoordinate(x: 0, y: 3), owner: .rival(1))
    market.world.testSetStock([.bread: 5], in: market.warehouse)
    market.world.testSetStock([.iron: 7], in: rivalWarehouse)
    market.world.buildings[market.warehouse]?.state = .constructing
    #expect(market.world.marketReach(at: market.townCenter)?.stock == [:])
}

@Test func onlyOperationalPlayerTownCentersHaveAMarket() {
    var market = MarketFixture()
    let rival = market.world.testPlace(.townCenter, at: TileCoordinate(x: 14, y: 3), owner: .rival(1))
    #expect(market.world.hasMarket(at: market.townCenter))
    #expect(market.world.marketReach(at: market.warehouse) == nil)
    #expect(!market.world.hasMarket(at: market.warehouse))
    #expect(market.world.marketReach(at: rival) == nil)
    #expect(!market.world.hasMarket(at: rival))
    market.world.buildings[market.townCenter]?.state = .constructing
    #expect(market.world.marketReach(at: market.townCenter) == nil)
    #expect(!market.world.hasMarket(at: market.townCenter))
}
