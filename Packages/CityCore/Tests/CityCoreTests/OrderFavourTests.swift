import Foundation
import Testing
@testable import CityCore

// Scenarios from openspec/changes/add-orders: research / Research cost
// scales with difficulty, rival-trade / Favour improves a rival's prices.

@Test("scenario: crown favour makes research cheaper")
func scenarioCrownFavourMakesResearchCheaper() {
    var world = World.fixtureWithTerrain(width: 8, height: 8, fill: .grass, seed: 1)
    #expect(world.researchCost(of: .milling) == 720)
    world.orders.favour.crown = 6
    #expect(world.researchCost(of: .milling) == 698)
    world.orders.favour.crown = 12
    #expect(world.researchCost(of: .milling) == 684)
    world.orders.favour.crown = 5
    #expect(world.researchCost(of: .milling) == 720)
}

@Test("scenario: favour step 1 improves prices")
func scenarioFavourStep1ImprovesPrices() {
    var world = TradeFixture().world
    world.orders.favour.adjust(.rival(1), by: 6)
    #expect(world.rivalPrice(.tools, .bought, from: 1) == 35)
    #expect(world.rivalPrice(.tools, .sold, from: 1) == 23)
}

@Test("scenario: favour step 2 improves prices")
func scenarioFavourStep2ImprovesPrices() {
    var world = TradeFixture().world
    world.orders.favour.adjust(.rival(1), by: 12)
    #expect(world.rivalPrice(.tools, .bought, from: 1) == 33)
    #expect(world.rivalPrice(.tools, .sold, from: 1) == 24)
}

@Test("scenario: favour with one rival does not change another's prices")
func scenarioFavourWithOneRivalDoesNotChangeAnothersPrices() {
    var world = TradeFixture().world
    world.orders.favour.adjust(.rival(1), by: 12)
    #expect(world.rivalPrice(.tools, .bought, from: 2) == 37)
    #expect(world.rivalPrice(.tools, .sold, from: 2) == 22)
    #expect(Good.tools.rivalPrice(.bought) == 37)
}

@Test func favourPricesNeverFallBelowOneDollar() {
    #expect(Good.grain.rivalPrice(.bought, bonusPercent: 10) >= 1)
    #expect(Good.grain.rivalPrice(.sold, bonusPercent: 0) == 2)
}

@Test func tradesAndOffersUseTheFavourPrices() {
    var fixture = TradeFixture()
    fixture.world.orders.favour.adjust(.rival(1), by: 12)
    fixture.setStock([.tools: 40, .wood: 4])
    #expect(fixture.world.sellOffers(of: 1).first { $0.good == .tools }?.price == 33)
    #expect(fixture.world.buyOffers(of: 1).first { $0.good == .wood }?.price == 3)
    fixture.dockShip(at: fixture.rivalPort, actions: [.loadUpTo(good: .tools, qty: 10)])
    fixture.world.economy.balance = 1000
    _ = fixture.dock()
    #expect(fixture.world.economy.balance == 1000 - 10 * 33, "balance \(fixture.world.economy.balance)")
}

@Test("scenario: orders survive a save and load")
func scenarioOrdersSurviveASaveAndLoad() throws {
    var fixture = OrdersFixture()
    fixture.world.testAddOrder(state: .accepted)
    fixture.world.orders.favour.adjust(.rival(2), by: 3)
    fixture.world.orders.fulfilledCount = 4
    fixture.world.orders.shipments = [OrderShipment(
        id: EntityID(raw: 9), order: 1, good: .planks, amount: 5,
        path: [TileCoordinate(x: 1, y: 2), TileCoordinate(x: 1, y: 3)], pathIndex: 1, from: fixture.warehouse, to: fixture.center
    )]
    let data = try JSONEncoder().encode(fixture.world)
    var decoded = try JSONDecoder().decode(World.self, from: data)
    #expect(decoded == fixture.world)
    decoded.tick()
    fixture.world.tick()
    #expect(decoded == fixture.world)
    #expect(decoded.orders.shipments.first?.pathIndex == 2 || decoded.orders.shipments.isEmpty)
}

@Test func aWorldWithoutOrdersDecodesAnEmptyState() throws {
    let fixture = OrdersFixture()
    let data = try JSONEncoder().encode(fixture.world)
    var object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    object.removeValue(forKey: "orders")
    let stripped = try JSONSerialization.data(withJSONObject: object)
    let decoded = try JSONDecoder().decode(World.self, from: stripped)
    #expect(decoded.orders == OrdersState())
}

@Test func issuersEncodeAsReadableStrings() throws {
    let encoded = try JSONEncoder().encode([OrderIssuer.crown, .rival(2)])
    #expect(String(data: encoded, encoding: .utf8) == "[\"crown\",\"rival-2\"]")
    #expect(try JSONDecoder().decode([OrderIssuer].self, from: encoded) == [.crown, .rival(2)])
    #expect(throws: DecodingError.self) { try JSONDecoder().decode(OrderIssuer.self, from: Data("\"mainland\"".utf8)) }
    #expect(throws: DecodingError.self) { try JSONDecoder().decode(OrderIssuer.self, from: Data("\"rival-x\"".utf8)) }
}
