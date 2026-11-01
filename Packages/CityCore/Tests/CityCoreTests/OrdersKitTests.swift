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

/// Wood the sawmills take as it is made never reaches the stores, so it
/// can't fill an order (#338).
@Test func theKitCountsOnlyTheOutputTheTownDoesNotUseItself() throws {
    var fixture = OrdersFixture()
    fixture.seedOutput([.wood: 60])
    for season in fixture.world.statistics.seasons.indices {
        fixture.world.statistics.seasons[season].goods[.wood]?.usedByProduction = 50
        fixture.world.statistics.seasons[season].goods[.wood]?.usedByConstruction = 10
    }
    let id = fixture.world.testAddOrder(good: .wood, quantity: 45)
    let order = try #require(fixture.world.order(id))
    #expect(!OrdersKit.canFill(order, in: fixture.world))
    for season in fixture.world.statistics.seasons.indices {
        fixture.world.statistics.seasons[season].goods[.wood]?.usedByProduction = 30
        fixture.world.statistics.seasons[season].goods[.wood]?.sold = 5
        fixture.world.statistics.seasons[season].goods[.wood]?.bought = 5
    }
    // 60 + 5 - 30 - 10 - 5 = 20 spare a season, 2 seasons at 150%: 60.
    #expect(OrdersKit.canFill(order, in: fixture.world))
}
