import Foundation
import Testing
@testable import CityCore

// rival-towns / Rival market trades (change rival-ai-viability, M2).

private func normalWorld() -> World {
    World.newGame(layout: .archipelago, seed: 0, difficulty: .normal)
}

private func rivalTrades(_ commands: [Command]) -> [Command] {
    commands.filter {
        switch $0 {
        case .rivalMarketBuy, .rivalMarketSell: true
        default: false
        }
    }
}

@Test("scenario: rival buys the planks it is missing")
func scenarioRivalBuysThePlanksItIsMissing() throws {
    var world = normalWorld()
    world.setRival(1) {
        $0.ai.scriptIndex = 3
        $0.treasury = 400
    }
    world.setRivalStock(1, [.wood: 10, .food: 10])
    let commands = world.takeTurn(1)
    // The purchase comes in the same batch as the house, ahead of it, so
    // no carrier can take the planks first.
    #expect(commands.first == .rivalMarketBuy(1, .planks, 4))
    #expect(placedKind(commands.last) == .house)
    let roads = Int64(commands.count { placedKind($0) == .road })
    world.tick()
    let price = Good.planks.marketPrice(.bought)
    #expect(world.rival(1)?.treasury == 400 - 4 * price - 50 - roads * 5)
    #expect(world.rival(1)?.market.traded(.planks, .bought) == 4)
    let house = try #require(placedAnchor(commands.last).flatMap { world.occupiedTiles[$0] }.flatMap { world.buildings[$0] })
    #expect(house.constructionState != .waitingForMaterials)
}

@Test("a step the rival's own sawmill can supply waits for it instead of buying")
func ownSawmillSuppliesTheStep() {
    var world = normalWorld()
    world.setRival(1) {
        $0.ai.scriptIndex = 3
        $0.treasury = 400
    }
    world.setRivalStock(1, [.wood: 10, .food: 10])
    world.testAddBuilding(.lumberjackHut, owner: .rival(1))
    world.testAddBuilding(.sawmill, owner: .rival(1))
    let commands = world.takeTurn(1)
    #expect(rivalTrades(commands).isEmpty)
    #expect(placedKind(commands.last) == .house)
}

@Test("scenario: rival in debt sells surplus planks")
func scenarioRivalInDebtSellsSurplusPlanks() {
    var world = normalWorld()
    world.setRival(1) { $0.treasury = -20 }
    world.setRivalStock(1, [.planks: 40])
    let commands = world.takeTurn(1)
    #expect(commands == [.rivalMarketSell(1, .planks, 20)])
    world.tick()
    #expect(world.rival(1)?.treasury == -20 + 20 * Good.planks.marketPrice(.sold))
    #expect(world.rivalStock(1)[.planks] == 20)
}

@Test("scenario: no purchase for a step the caps rule out")
func noUnblockingBuyAtTheBuildingCap() {
    var world = normalWorld()
    world.setRival(1) {
        $0.ai.scriptIndex = 3
        $0.treasury = 400
    }
    world.setRivalStock(1, [.wood: 10, .food: 10])
    for _ in 0 ..< world.difficulty.rivalBuildingCap {
        world.testAddBuilding(.farm, owner: .rival(1))
    }
    #expect(rivalTrades(world.takeTurn(1)).isEmpty)
}

@Test("no unblocking buy for a house step the house cap skips")
func noUnblockingBuyAtTheHouseCap() {
    var world = normalWorld()
    world.setRival(1) {
        $0.ai.scriptIndex = 3
        $0.treasury = 400
    }
    world.setRivalStock(1, [.wood: 10, .food: 10])
    // Below the building cap, so only the house cap stands in the way.
    for _ in 0 ..< world.difficulty.rivalHouseCap {
        world.testAddBuilding(.house, owner: .rival(1))
    }
    #expect(!rivalTrades(world.takeTurn(1)).contains(.rivalMarketBuy(1, .planks, 4)))
}

@Test("a rival short of money but not in debt sells surplus")
func rivalShortOfMoneySellsSurplus() {
    var world = normalWorld()
    world.setRival(1) { $0.treasury = 100 }
    world.setRivalStock(1, [.planks: 30])
    #expect(world.takeTurn(1) == [.rivalMarketSell(1, .planks, 18)])
    var comfortable = normalWorld()
    comfortable.setRival(1) { $0.treasury = 150 }
    comfortable.setRivalStock(1, [.planks: 30])
    #expect(rivalTrades(comfortable.takeTurn(1)).isEmpty)
}

@Test("scenario: rival clears a full town center")
func scenarioRivalClearsAFullTownCenter() {
    var world = normalWorld()
    world.setRival(1) { $0.treasury = 5000 }
    world.setRivalStock(1, [.planks: 38, .food: 2])
    #expect(world.takeTurn(1) == [.rivalMarketSell(1, .planks, 20)])
}

@Test("a full but fed town does not sell")
func fullButFedTownDoesNotSell() {
    var world = normalWorld()
    world.setRival(1) { $0.treasury = 5000 }
    world.setRivalStock(1, [.planks: 30, .food: 10])
    #expect(rivalTrades(world.takeTurn(1)).isEmpty)
}

@Test("clearing the store sells from the town center first")
func clearingTheStoreSellsFromTheTownCenterFirst() throws {
    var world = normalWorld()
    world.setRival(1) { $0.treasury = 5000 }
    world.setRivalStock(1, [.planks: 38, .food: 2])
    // A warehouse that holds planks too.
    let rival = try #require(world.rival(1))
    let center = try #require(world.buildings[rival.townCenterID])
    let warehouse = world.testPlace(.warehouse, at: TileCoordinate(x: center.anchor.x + 5, y: center.anchor.y), owner: .rival(1))
    world.testSetStock([.planks: 30], in: warehouse)
    world.enqueue(.rivalMarketSell(1, .planks, 20))
    world.tick()
    #expect(world.stockpiles[rival.townCenterID]?.quantity(of: .planks) == 18)
    #expect(world.stockpiles[warehouse]?.quantity(of: .planks) == 30)
}

@Test("scenario: rival sells surplus planks from crowded stores")
func scenarioRivalSellsSurplusPlanksFromCrowdedStores() throws {
    var world = normalWorld()
    world.setRival(1) { $0.treasury = 5000 }
    // A full town center with food to spare, so the rival doesn't sell
    // to clear it; 60 planks and filler iron in a warehouse beside it.
    world.setRivalStock(1, [.planks: 30, .food: 10])
    let rival = try #require(world.rival(1))
    let center = try #require(world.buildings[rival.townCenterID])
    let warehouse = world.testPlace(.warehouse, at: TileCoordinate(x: center.anchor.x + 5, y: center.anchor.y), owner: .rival(1))
    var roomy = world
    world.testSetStock([.planks: 60, .iron: 110], in: warehouse)
    #expect(world.takeTurn(1) == [.rivalMarketSell(1, .planks, 20)])
    roomy.testSetStock([.planks: 60, .iron: 90], in: warehouse)
    #expect(rivalTrades(roomy.takeTurn(1)).isEmpty)
}

@Test("wood bought for a step is in the same batch as the step, ahead of it")
func boughtWoodComesInTheStepsBatch() throws {
    var world = normalWorld()
    world.setRival(1) {
        $0.ai.scriptIndex = 12
        $0.treasury = 1000
    }
    // One house wants a farm (2 wood), with no wood in stock and no forest
    // in reach. The purchase must come in the farm's own batch, ahead of
    // it: the farm's materials are then deducted when it is placed, at the
    // same tick boundary, before any carrier could take the wood to a
    // sawmill. A purchase on an earlier turn lost that race.
    world.setRivalStock(1, [.planks: 10, .food: 0])
    world.testAddBuilding(.house, owner: .rival(1))
    world.testAddBuilding(.sawmill, owner: .rival(1))
    let commands = world.takeTurn(1)
    #expect(commands.first == .rivalMarketBuy(1, .wood, 2))
    #expect(placedKind(commands.last) == .farm)
    world.tick()
    let farm = try #require(placedAnchor(commands.last).flatMap { world.occupiedTiles[$0] }.flatMap { world.buildings[$0] })
    #expect(farm.kind == .farm)
    #expect(farm.constructionState != .waitingForMaterials)
}

@Test("scenario: rival buys food for short houses")
func scenarioRivalBuysFoodForShortHouses() {
    var world = normalWorld()
    world.setRival(1) {
        $0.ai.scriptIndex = 12
        $0.treasury = 500
    }
    world.setRivalStock(1, [.wood: 10, .planks: 10, .food: 1])
    let house = world.testAddHouse(owner: .rival(1), residents: 4)
    world.populations[house]?.setShort(.food, true)
    let commands = world.takeTurn(1)
    #expect(commands == [.rivalMarketBuy(1, .food, 5)])
}

@Test("scenario: no purchase into a full town center")
func scenarioNoPurchaseIntoAFullTownCenter() {
    var world = normalWorld()
    world.setRival(1) {
        $0.ai.scriptIndex = 12
        $0.treasury = 500
    }
    // 40 units fill the town center, none of them surplus it would sell.
    world.setRivalStock(1, [.wood: 12, .planks: 12, .iron: 15, .food: 1])
    let house = world.testAddHouse(owner: .rival(1), residents: 4)
    world.populations[house]?.setShort(.food, true)
    let commands = world.takeTurn(1)
    #expect(rivalTrades(commands).isEmpty)
    #expect(!commands.isEmpty)
}

@Test("scenario: rival limits are its own")
func scenarioRivalLimitsAreItsOwn() throws {
    var world = normalWorld()
    world.setRival(1) {
        $0.ai.scriptIndex = 12
        $0.treasury = 500
        $0.market.record(10, of: .food, .bought)
    }
    world.setRivalStock(1, [.wood: 10, .planks: 10, .food: 1])
    let house = world.testAddHouse(owner: .rival(1), residents: 4)
    world.populations[house]?.setShort(.food, true)
    #expect(rivalTrades(world.takeTurn(1)).isEmpty)
    let center = try #require(world.goodsBuffers(of: .player).first { $0.kind == .townCenter }?.id)
    world.testSetStock([:], in: center)
    world.enqueue(.marketBuy(center, .food, 10))
    world.tick()
    #expect(world.market.traded(.food, .bought) == 10)
    #expect(world.rival(1)?.market.traded(.food, .bought) == 10)
    // The season turns: the rival's count resets with the player's.
    _ = world.testRun(ticks: Int(CalendarState.ticksPerSeason))
    #expect(world.rival(1)?.market.traded(.food, .bought) == 0)
}

@Test("scenario: rival trades leave the player alone")
func scenarioRivalTradesLeaveThePlayerAlone() {
    var world = normalWorld()
    world.setRivalStock(1, [.planks: 40])
    let balance = world.economy.balance
    let playerStock = world.goodsBuffers(of: .player).map { world.stockpiles[$0.id] }
    world.enqueue(.rivalMarketSell(1, .planks, 20))
    let events = world.tick().events
    #expect(world.rivalStock(1)[.planks] == 20)
    #expect(world.economy.balance == balance)
    #expect(world.goodsBuffers(of: .player).map { world.stockpiles[$0.id] } == playerStock)
    #expect(world.market == MarketLedger())
    #expect(!events.contains { if case .marketTraded = $0 { true } else { false } })
}

@Test("a rival's market counts survive a save, and older saves load with none")
func rivalMarketCountsPersist() throws {
    var world = normalWorld()
    world.setRival(1) { $0.market.record(3, of: .planks, .sold) }
    let data = try JSONEncoder().encode(world)
    let loaded = try JSONDecoder().decode(World.self, from: data)
    #expect(loaded.rival(1)?.market.traded(.planks, .sold) == 3)

    let rival = try #require(world.rival(1))
    var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(rival)) as? [String: Any])
    object.removeValue(forKey: "market")
    let old = try JSONDecoder().decode(RivalTown.self, from: JSONSerialization.data(withJSONObject: object))
    #expect(old.market == MarketLedger())
}
