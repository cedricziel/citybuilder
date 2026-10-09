import Foundation
import Testing
@testable import CityCore

// rival-trade scenarios (openspec/changes/add-rival-trade, M1): rival
// ports, base prices and offers.

/// Rival 1 of a Normal archipelago with `houses` houses, $500, 10 wood,
/// 8 planks and 20 food.
private func portReadyWorld(houses: Int = 6) -> World {
    var world = World.newGame(layout: .archipelago, seed: 0, difficulty: .normal)
    world.setRival(1) { $0.treasury = 500 }
    world.setRivalStock(1, [.wood: 10, .planks: 8, .food: 20])
    for _ in 0 ..< houses {
        world.testAddBuilding(.house, owner: .rival(1))
    }
    return world
}

/// Anchors around `center` ring by ring out to `radius`, each ring
/// row-major, as design D1 orders the port search. Written out here on
/// purpose, as an oracle independent of the AI's search.
private func spiral(around center: TileCoordinate, radius: Int) -> [TileCoordinate] {
    (0 ... radius).flatMap { ring in
        (-ring ... ring).flatMap { dy in
            (-ring ... ring).compactMap { dx in
                max(abs(dx), abs(dy)) == ring ? TileCoordinate(x: center.x + dx, y: center.y + dy) : nil
            }
        }
    }
}

// MARK: - Rivals build a port

@Test("scenario: rival places its port")
func scenarioRivalPlacesItsPort() throws {
    var world = portReadyWorld()
    let rival = try #require(world.rival(1))
    let center = try #require(world.buildings[rival.townCenterID]).anchor
    let expected = spiral(around: center, radius: 40).first { world.canPlace(.port, at: $0, for: rival.owner) == .allowed }
    let commands = world.takeTurn(1)
    #expect(commands.count == 1)
    guard case let .rivalPlace(1, .port, anchor) = try #require(commands.first) else {
        Issue.record("expected a port placement, got \(commands)")
        return
    }
    #expect(anchor == expected)
    #expect(world.rival(1)?.ai.scriptIndex == rival.ai.scriptIndex)
    world.tick()
    let port = try #require(world.occupiedTiles[anchor].flatMap { world.buildings[$0] })
    #expect(port.kind == .port)
    #expect(port.owner == rival.owner)
    #expect(port.landFaceTiles.allSatisfy { world.islandID(at: $0) == rival.islandID })
    #expect(!port.seaFaceTiles.isEmpty)
    #expect(port.constructionState == .actively)
}

@Test("scenario: too small for a port")
func scenarioTooSmallForAPort() {
    var world = portReadyWorld(houses: 5)
    #expect(!world.takeTurn(1).contains { placedKind($0) == .port })
}

@Test("a rival with a port builds no second one")
func rivalWithAPortBuildsNoSecond() {
    var world = portReadyWorld()
    world.testAddBuilding(.port, owner: .rival(1))
    #expect(!world.takeTurn(1).contains { placedKind($0) == .port })
}

@Test("a port the rival can't afford holds the script, then is suspended for 100 turns")
func unaffordablePortIsSuspended() throws {
    var world = portReadyWorld()
    // One dollar short of the port's $250 plus the $50 margin.
    world.setRival(1) { $0.treasury = 299 }
    for turn in 1 ... 10 {
        #expect(world.takeTurn(1).isEmpty, "turn \(turn)")
    }
    let ai = try #require(world.rival(1)?.ai)
    #expect(ai.scriptIndex == 0)
    #expect(ai.portWaitTurns == 0)
    #expect(ai.portRetryTick == world.tickCount + 100 * world.difficulty.rivalTurnTicks)
    // Rich again, but the rule is suspended: the script takes the turn.
    world.setRival(1) { $0.treasury = 1000 }
    let next = world.takeTurn(1)
    #expect(placedKind(next.last) == .lumberjackHut)
    #expect(world.rival(1)?.ai.scriptIndex == 1)
}

@Test("a rival's port costs money but no materials")
func rivalPortCostsNoMaterials() {
    var world = portReadyWorld()
    // Too little wood and no planks for the player's price of a port.
    world.setRivalStock(1, [.wood: 4, .food: 20])
    #expect(world.materialCost(of: .port, for: .rival(1)).isEmpty)
    #expect(world.materialCost(of: .port, for: .player) == [.wood: 8, .planks: 6])
    let commands = world.takeTurn(1)
    #expect(commands.count == 1)
    #expect(placedKind(commands.first) == .port)
    world.tick()
    #expect(world.rival(1)?.treasury == 250)
    #expect(world.buildings.values.contains { $0.kind == .port && $0.owner == .rival(1) && $0.constructionState == .actively })
}

@Test("ai state from a rival-towns save reads the port counters as zero")
func aiStateDecodesWithoutPortCounters() throws {
    let state = try JSONDecoder().decode(RivalAIState.self, from: Data(#"{"scriptIndex":3,"waitTurns":2}"#.utf8))
    #expect(state.scriptIndex == 3)
    #expect(state.waitTurns == 2)
    #expect(state.portWaitTurns == 0)
    #expect(state.portRetryTick == 0)
    let saved = RivalAIState(scriptIndex: 4, waitTurns: 1, portWaitTurns: 3, portRetryTick: 900)
    #expect(try JSONDecoder().decode(RivalAIState.self, from: JSONEncoder().encode(saved)) == saved)
}

// MARK: - Base prices

@Test("scenario: tool prices")
func scenarioToolPrices() {
    #expect(Good.tools.rivalSellPrice == 37)
    #expect(Good.tools.rivalBuyPrice == 22)
}

@Test("scenario: grain buy price floor")
func scenarioGrainBuyPriceFloor() {
    #expect(Good.grain.rivalBuyPrice == 2)
}

@Test("scenario: every good is priced")
func scenarioEveryGoodHasRivalPrices() {
    for good in Good.allCases {
        #expect(good.basePrice >= 1, "\(good)")
        #expect(good.rivalBuyPrice >= 1, "\(good)")
        #expect(good.rivalSellPrice > good.rivalBuyPrice, "\(good)")
    }
}

@Test("rival prices follow the design table")
func rivalPriceTable() {
    let table: [Good: (sell: Int64, buy: Int64)] = [
        .wood: (5, 3), .planks: (10, 6), .food: (5, 3), .bread: (15, 9), .grain: (3, 2),
        .flour: (7, 4), .ore: (6, 3), .charcoal: (6, 3), .iron: (17, 10), .tools: (37, 22)
    ]
    for (good, prices) in table {
        #expect(good.rivalSellPrice == prices.sell, "\(good)")
        #expect(good.rivalBuyPrice == prices.buy, "\(good)")
    }
}

// MARK: - Rival offers

@Test("scenario: surplus for sale")
func scenarioSurplusForSale() {
    var fixture = TradeFixture()
    fixture.setStock([.wood: 42, .planks: 12])
    #expect(fixture.world.sellOffers(of: 1) == [RivalOffer(good: .wood, quantity: 12, price: 5)])
    #expect(fixture.world.buyOffers(of: 1) == [
        RivalOffer(good: .planks, quantity: 8, price: 6),
        RivalOffer(good: .food, quantity: 20, price: 3),
        RivalOffer(good: .bread, quantity: 20, price: 9),
        RivalOffer(good: .tools, quantity: 20, price: 22)
    ])
}

@Test("scenario: never both")
func scenarioNeverBoth() {
    var fixture = TradeFixture()
    fixture.setStock([.food: 25])
    #expect(!fixture.world.sellOffers(of: 1).contains { $0.good == .food })
    #expect(!fixture.world.buyOffers(of: 1).contains { $0.good == .food })
}

@Test("offers count every buffer of the rival")
func offersCountEveryBuffer() {
    var fixture = TradeFixture()
    fixture.setStock([.wood: 20])
    fixture.setStock([.wood: 15], in: fixture.townCenter)
    fixture.setStock([.wood: 1], in: fixture.rivalPort)
    #expect(fixture.world.sellOffers(of: 1) == [RivalOffer(good: .wood, quantity: 6, price: 5)])
    #expect(fixture.world.sellOffers(of: 2).isEmpty)
}
