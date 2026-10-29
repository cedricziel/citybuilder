import Foundation
import Testing
@testable import CityCore

// Scenarios from openspec/changes/add-orders (orders / Crown orders are
// delivered by shipments from the stores, Rival orders are delivered by
// ship, Orders and per-good storage) and rival-trade.

private func accepted(_ fixture: inout OrdersFixture, quantity: Int = 30, deadline: UInt64? = nil) -> OrderID {
    fixture.world.testAddOrder(quantity: quantity, state: .accepted, deadline: deadline)
}

@Test("scenario: dispatch sends the goods from the stores")
func scenarioDispatchSendsTheGoodsFromTheStores() {
    var fixture = OrdersFixture()
    let id = accepted(&fixture)
    fixture.setStock([.planks: 15], in: fixture.center)
    fixture.setStock([.planks: 20], in: fixture.warehouse)
    fixture.world.enqueue(.dispatchOrder(id))
    fixture.world.tick()
    #expect(fixture.world.order(id)?.delivered == 15)
    #expect(fixture.stock(.planks, in: fixture.center) == 0)
    #expect(fixture.stock(.planks, in: fixture.warehouse) == 5)
    #expect(fixture.world.orders.shipments.count == 1)
    #expect(fixture.world.orders.shipments.first?.amount == 15)
    #expect(fixture.world.orders.shipments.first?.to == fixture.center)
}

@Test("scenario: dispatch is refused when the stores hold too little")
func scenarioDispatchIsRefusedWhenTheStoresHoldTooLittle() {
    var fixture = OrdersFixture()
    let id = accepted(&fixture)
    fixture.setStock([.planks: 9], in: fixture.center)
    fixture.setStock([.planks: 20], in: fixture.warehouse)
    #expect(fixture.world.orderDispatch(for: id) == .unavailable(.short(available: 29)))
    fixture.world.enqueue(.dispatchOrder(id))
    fixture.world.tick()
    #expect(fixture.world.order(id)?.delivered == 0)
    #expect(fixture.stock(.planks, in: fixture.warehouse) == 20)
    #expect(fixture.stock(.planks, in: fixture.center) == 9)
    #expect(fixture.world.orders.shipments.isEmpty)
}

@Test("scenario: dispatch is refused when it would arrive late")
func scenarioDispatchIsRefusedWhenItWouldArriveLate() {
    var fixture = OrdersFixture()
    fixture.setStock([.planks: 30], in: fixture.warehouse)
    let probe = accepted(&fixture)
    guard case let .ready(plan) = fixture.world.orderDispatch(for: probe) else {
        Issue.record("no plan")
        return
    }
    let steps = UInt64(plan.legs[0].path.count - 1)
    #expect(steps > 5)
    let now = fixture.world.tickCount
    let late = accepted(&fixture, deadline: now + steps - 1)
    #expect(fixture.world.orderDispatch(for: late) == .unavailable(.late))
    fixture.world.enqueue(.dispatchOrder(late))
    fixture.world.tick()
    #expect(fixture.stock(.planks, in: fixture.warehouse) == 30)
    let punctual = accepted(&fixture, deadline: now + steps + 5)
    if case .ready = fixture.world.orderDispatch(for: punctual) {} else { Issue.record("expected a plan") }
}

@Test("scenario: goods in the town center count at once")
func scenarioGoodsInTheTownCenterCountAtOnce() {
    var fixture = OrdersFixture()
    let id = accepted(&fixture)
    fixture.setStock([.planks: 30], in: fixture.center)
    fixture.world.enqueue(.dispatchOrder(id))
    let events = fixture.world.tick().events
    #expect(fixture.world.order(id)?.state == .fulfilled)
    #expect(events.contains { if case .orderFulfilled(id, _) = $0 { true } else { false } })
    #expect(fixture.world.orders.shipments.isEmpty)
}

@Test("scenario: shipments walk the road and arrive")
func scenarioShipmentsWalkTheRoadAndArrive() throws {
    var fixture = OrdersFixture()
    let id = accepted(&fixture)
    fixture.setStock([.planks: 30], in: fixture.warehouse)
    fixture.world.enqueue(.dispatchOrder(id))
    fixture.world.tick()
    let shipment = try #require(fixture.world.orders.shipments.first)
    func carrier() -> Carrier? {
        fixture.world.snapshot().carriers.first { $0.id == shipment.id }
    }
    let first = try #require(carrier())
    fixture.world.tick()
    let second = try #require(carrier())
    #expect(second.pathIndex == first.pathIndex + 1)
    #expect(second.path == shipment.path)
    if case let .deliver(good, amount, from, to) = second.mission {
        #expect(good == .planks && amount == 30 && from == fixture.warehouse && to == fixture.center)
    } else {
        Issue.record("expected a deliver mission")
    }
    #expect(fixture.world.order(id)?.delivered == 0)
    fixture.run(to: fixture.world.tickCount + UInt64(shipment.path.count))
    #expect(fixture.world.order(id)?.state == .fulfilled)
    #expect(carrier() == nil)
}

@Test("scenario: a rival's order cannot be dispatched")
func scenarioARivalsOrderCannotBeDispatched() {
    var fixture = OrdersFixture()
    let id = fixture.world.testAddOrder(.rival(1), state: .accepted)
    fixture.setStock([.planks: 30], in: fixture.center)
    let before = fixture.world.orders
    #expect(fixture.world.orderDispatch(for: id) == .unavailable(.notDispatchable))
    fixture.world.enqueue(.dispatchOrder(id))
    fixture.world.tick()
    #expect(fixture.world.orders == before)
    #expect(fixture.stock(.planks, in: fixture.center) == 30)
}

@Test("scenario: dispatch frees room for a stopped producer")
func scenarioDispatchFreesRoomForAStoppedProducer() {
    var fixture = OrdersFixture()
    let sawmill = fixture.world.testPlace(.sawmill, at: TileCoordinate(x: 15, y: 18), owner: .player)
    for tile in [TileCoordinate(x: 14, y: 18), TileCoordinate(x: 14, y: 19)] {
        fixture.world.testRoad(at: tile)
    }
    fixture.setStock([.planks: 40], in: fixture.center)
    fixture.setStock([.planks: 80], in: fixture.warehouse)
    fixture.world.testSetStock([.wood: 8, .planks: 16], in: sawmill)
    fixture.run(to: 60)
    #expect(fixture.world.productions[sawmill]?.isStalled == true)
    let id = accepted(&fixture, quantity: 40)
    fixture.world.enqueue(.dispatchOrder(id))
    fixture.run(to: fixture.world.tickCount + 40)
    #expect(fixture.world.stockpiles[sawmill]?.quantity(of: .planks) ?? 16 < 16)
    #expect(fixture.world.productions[sawmill]?.isStalled == false)
}

@Test("scenario: goods on the road are not stored")
func scenarioGoodsOnTheRoadAreNotStored() {
    var fixture = OrdersFixture()
    let sawmill = fixture.world.testPlace(.sawmill, at: TileCoordinate(x: 15, y: 18), owner: .player)
    fixture.world.testSetStock([.planks: 12], in: sawmill)
    fixture.world.carriers[EntityID(raw: 700)] = Carrier(
        id: EntityID(raw: 700), path: [TileCoordinate(x: 13, y: 12)],
        mission: .deliver(good: .planks, amount: 3, fromProducer: sawmill, toWarehouse: fixture.center)
    )
    let id = accepted(&fixture)
    #expect(fixture.world.orderAvailable(for: id) == 0)
    #expect(fixture.world.orderDispatch(for: id) == .unavailable(.short(available: 0)))
}

@Test func aStoreWithoutARoadCannotShip() {
    var fixture = OrdersFixture()
    let lone = fixture.world.testPlace(.warehouse, at: TileCoordinate(x: 30, y: 30), owner: .player)
    fixture.setStock([.planks: 50], in: lone)
    let id = accepted(&fixture)
    #expect(fixture.world.orderDispatch(for: id) == .unavailable(.short(available: 0)))
}

@Test func aTownWithoutACenterCannotDispatch() {
    var fixture = OrdersFixture()
    fixture.world.buildings[fixture.center]?.state = .constructing
    let id = accepted(&fixture)
    #expect(fixture.world.orderDispatch(for: id) == .unavailable(.noRoad))
}

@Test func aSecondDispatchDoesNothing() {
    var fixture = OrdersFixture()
    let id = accepted(&fixture)
    fixture.setStock([.planks: 60], in: fixture.warehouse)
    fixture.world.enqueue(.dispatchOrder(id))
    fixture.world.tick()
    #expect(fixture.world.orderDispatch(for: id) == .unavailable(.notDispatchable))
    fixture.world.enqueue(.dispatchOrder(id))
    fixture.world.tick()
    #expect(fixture.stock(.planks, in: fixture.warehouse) == 30)
}

@Test func aShipmentSurvivesItsDemolishedTownCenter() {
    var fixture = OrdersFixture()
    let id = accepted(&fixture)
    fixture.setStock([.planks: 30], in: fixture.warehouse)
    fixture.world.enqueue(.dispatchOrder(id))
    fixture.world.tick()
    fixture.world.buildings.removeValue(forKey: fixture.center)
    fixture.world.stockpiles.removeValue(forKey: fixture.center)
    fixture.run(to: fixture.world.tickCount + 40)
    #expect(fixture.world.order(id)?.state == .fulfilled)
}

@Test func aShipmentForAClosedOrderGoesBack() {
    var fixture = OrdersFixture()
    let id = accepted(&fixture)
    fixture.world.orders.shipments = [OrderShipment(
        id: EntityID(raw: 800), order: 999, good: .planks, amount: 5,
        path: [TileCoordinate(x: 13, y: 12)], from: fixture.warehouse, to: fixture.center
    )]
    fixture.world.tick()
    #expect(fixture.world.orders.shipments.isEmpty)
    #expect(fixture.world.order(id)?.delivered == 0)
    #expect(fixture.stock(.planks, in: fixture.warehouse) == 5)
}

@Test func aReturningShipmentFindsAnotherStoreWhenItsOwnIsFull() {
    var fixture = OrdersFixture()
    let id = accepted(&fixture)
    fixture.setStock([.planks: 80], in: fixture.warehouse)
    fixture.world.orders.shipments = [OrderShipment(
        id: EntityID(raw: 800), order: 999, good: .planks, amount: 5,
        path: [TileCoordinate(x: 13, y: 12)], from: fixture.warehouse, to: fixture.center
    )]
    fixture.world.tick()
    #expect(fixture.stock(.planks, in: fixture.warehouse) == 80)
    #expect(fixture.stock(.planks, in: fixture.center) == 5)
    #expect(fixture.world.order(id)?.delivered == 0)
}

// MARK: - Rival delivery

private func rivalOrder(stock: [Good: Int] = [.planks: 6], quantity: Int = 30) -> (TradeFixture, OrderID) {
    var fixture = TradeFixture()
    fixture.world.calendar = CalendarState(startYear: 1200, isActive: true)
    fixture.setStock(stock)
    let id = fixture.world.testAddOrder(.rival(1), good: .planks, quantity: quantity, state: .accepted, reward: 120)
    return (fixture, id)
}

@Test("scenario: units sold at the rival's port count")
func scenarioUnitsSoldAtTheRivalsPortCount() {
    var (fixture, id) = rivalOrder()
    fixture.dockShip(at: fixture.rivalPort, actions: [.unloadUpTo(good: .planks, qty: 12)], cargo: [.planks: 12])
    _ = fixture.dock()
    #expect(fixture.world.order(id)?.delivered == 12)
    #expect(fixture.world.economy.balance > 1000)
}

@Test("scenario: units sold before accepting do not count")
func scenarioUnitsSoldBeforeAcceptingDoNotCount() {
    var (fixture, id) = rivalOrder()
    fixture.world.orders.orders[0].state = .offered
    fixture.dockShip(at: fixture.rivalPort, actions: [.unloadUpTo(good: .planks, qty: 12)], cargo: [.planks: 12])
    _ = fixture.dock()
    fixture.world.enqueue(.acceptOrder(id))
    fixture.world.tick()
    #expect(fixture.world.order(id)?.state == .accepted)
    #expect(fixture.world.order(id)?.delivered == 0)
}

@Test("scenario: a rival buys above its target for an accepted order")
func scenarioARivalBuysAboveItsTargetForAnAcceptedOrder() {
    var (fixture, id) = rivalOrder(stock: [.planks: 18])
    fixture.dockShip(at: fixture.rivalPort, actions: [.unloadUpTo(good: .planks, qty: 30)], cargo: [.planks: 30])
    let events = fixture.dock()
    #expect(fixture.world.order(id)?.delivered == 30)
    #expect(events == [.tradeCompleted(rival: 1, good: .planks, quantity: 30, total: 180, direction: .sold)])
    var plain = TradeFixture()
    plain.setStock([.planks: 18])
    plain.dockShip(at: plain.rivalPort, actions: [.unloadUpTo(good: .planks, qty: 30)], cargo: [.planks: 30])
    #expect(plain.dock() == [.tradeCompleted(rival: 1, good: .planks, quantity: 2, total: 12, direction: .sold)])
}

@Test("scenario: fulfilling a rival order")
func scenarioFulfillingARivalOrder() {
    var (fixture, id) = rivalOrder(quantity: 12)
    fixture.dockShip(at: fixture.rivalPort, actions: [.unloadUpTo(good: .planks, qty: 12)], cargo: [.planks: 12])
    _ = fixture.dock()
    let balance = fixture.world.economy.balance
    var events: [WorldEvent] = []
    fixture.world.runOrderSystem(events: &events)
    #expect(fixture.world.order(id)?.state == .fulfilled)
    #expect(fixture.world.economy.balance == balance + 120)
    #expect(fixture.world.orders.favour.value(for: .rival(1)) == 2)
    #expect(events == [.orderFulfilled(order: id, reward: 120)])
}

@Test func unitsBeyondTheOrderAreOrdinarySales() {
    var (fixture, id) = rivalOrder(quantity: 10)
    fixture.dockShip(at: fixture.rivalPort, actions: [.unloadUpTo(good: .planks, qty: 14)], cargo: [.planks: 14])
    _ = fixture.dock()
    #expect(fixture.world.order(id)?.delivered == 10)
}

@Test func anotherGoodOrAnotherRivalDoesNotCount() {
    var (fixture, id) = rivalOrder()
    fixture.world.orders.orders[0] = Order(
        id: id, template: .rivalTimber, issuer: .rival(2), good: .planks, quantity: 30, reward: 120,
        favourGain: 2, favourLoss: 2, issuedTick: 0, offerEndsTick: 1, deadlineTick: 9000, state: .accepted
    )
    fixture.dockShip(at: fixture.rivalPort, actions: [.unloadUpTo(good: .planks, qty: 12)], cargo: [.planks: 12])
    _ = fixture.dock()
    #expect(fixture.world.order(id)?.delivered == 0)
}

@Test("scenario: a returning shipment passes a burning store by")
func aReturningShipmentPassesABurningStoreBy() {
    var fixture = OrdersFixture()
    _ = accepted(&fixture)
    fixture.world.buildings[fixture.warehouse]?.state = .burning
    fixture.world.orders.shipments = [OrderShipment(
        id: EntityID(raw: 800), order: 999, good: .planks, amount: 5,
        path: [TileCoordinate(x: 13, y: 12)], from: fixture.warehouse, to: fixture.center
    )]
    fixture.world.tick()
    #expect(fixture.stock(.planks, in: fixture.warehouse) == 0)
    #expect(fixture.stock(.planks, in: fixture.center) == 5)
}
