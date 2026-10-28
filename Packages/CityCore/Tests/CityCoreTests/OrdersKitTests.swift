import Testing
@testable import CityCore

// The PlayerBot's order kit keeps back what the houses consume.

@Test func theKitKeepsBackASeasonsOfWhatTheHousesUse() throws {
    var fixture = OrdersFixture()
    fixture.seedOutput([.tools: 0])
    fixture.world.statistics.seasons[3].goods[.tools]?.usedByHouses = 20
    let id = fixture.world.testAddOrder(good: .tools, quantity: 12, deadline: 700)
    #expect(OrdersKit.consumption(of: .tools, in: fixture.world) == 20)
    // Nobody lives here yet, so only food is kept for the next tier.
    #expect(OrdersKit.reserved(in: fixture.world) == [.food])
    fixture.setStock([.tools: 25], in: fixture.center)
    var order = try #require(fixture.world.order(id))
    #expect(!OrdersKit.canFill(order, in: fixture.world))
    fixture.setStock([.tools: 40], in: fixture.center)
    order = try #require(fixture.world.order(id))
    #expect(OrdersKit.canFill(order, in: fixture.world))
    #expect(OrdersKit.consumption(of: .bread, in: fixture.world) == 0)
}

@Test func theKitWaitsWhileAMarketSaleSpendsTheSameStock() {
    var fixture = OrdersFixture()
    let id = fixture.world.testAddOrder(good: .planks, quantity: 10, state: .accepted)
    fixture.setStock([.planks: 30], in: fixture.center)
    var kit = OrdersKit()
    fixture.world.enqueue(.marketSell(fixture.center, .planks, 25))
    kit.takeTurn(&fixture.world)
    #expect(!fixture.world.pendingCommands.contains(.dispatchOrder(id)))
    fixture.world.pendingCommands.removeAll()
    kit.takeTurn(&fixture.world)
    #expect(fixture.world.pendingCommands.contains(.dispatchOrder(id)))
}
