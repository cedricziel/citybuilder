import Foundation
import Testing
@testable import CityCore

// Scenarios from openspec/changes/add-orders (orders / The player accepts,
// declines and abandons orders, Fulfilling an order pays money and favour,
// Missing a deadline costs favour, Favour has steps, An ignored order
// changes nothing else) and difficulty-and-goals / Orders goal.

// MARK: - Accepting, declining, abandoning

@Test("scenario: accepting an offer")
func scenarioAcceptingAnOffer() {
    var fixture = OrdersFixture()
    let id = fixture.world.testAddOrder()
    fixture.world.enqueue(.acceptOrder(id))
    let events = fixture.world.tick().events
    #expect(fixture.world.order(id)?.state == .accepted)
    #expect(events.contains(.orderAccepted(order: id)))
}

@Test("scenario: at most two orders are accepted")
func scenarioAtMostTwoOrdersAreAccepted() {
    var fixture = OrdersFixture()
    fixture.world.testAddOrder(state: .accepted)
    fixture.world.testAddOrder(.rival(1), state: .accepted)
    let third = fixture.world.testAddOrder()
    fixture.world.enqueue(.acceptOrder(third))
    let events = fixture.world.tick().events
    #expect(fixture.world.order(third)?.state == .offered)
    #expect(!events.contains(.orderAccepted(order: third)))
}

@Test("scenario: declining an offer")
func scenarioDecliningAnOffer() {
    var fixture = OrdersFixture()
    let id = fixture.world.testAddOrder()
    fixture.world.enqueue(.declineOrder(id))
    fixture.world.tick()
    #expect(fixture.world.order(id)?.state == .declined)
    #expect(fixture.world.orders.favour == FavourLedger())
}

@Test("scenario: abandoning an accepted order costs favour")
func scenarioAbandoningAnAcceptedOrderCostsFavour() {
    var fixture = OrdersFixture()
    let id = fixture.world.testAddOrder(state: .accepted, favourLoss: 3)
    let balance = fixture.world.economy.balance
    fixture.world.enqueue(.abandonOrder(id))
    let events = fixture.world.tick().events
    #expect(fixture.world.order(id)?.state == .failed)
    #expect(fixture.world.orders.favour.crown == -3)
    #expect(fixture.world.economy.balance == balance)
    #expect(events.contains(.orderFailed(order: id)))
}

@Test("scenario: commands on closed orders do nothing")
func scenarioCommandsOnClosedOrdersDoNothing() {
    var fixture = OrdersFixture()
    let expired = fixture.world.testAddOrder(state: .expired)
    let declined = fixture.world.testAddOrder(state: .declined)
    let before = fixture.world.orders
    fixture.world.enqueue(.acceptOrder(expired))
    fixture.world.enqueue(.abandonOrder(99))
    fixture.world.enqueue(.dispatchOrder(declined))
    fixture.world.enqueue(.declineOrder(expired))
    let events = fixture.world.tick().events
    #expect(fixture.world.orders == before)
    #expect(events.isEmpty)
}

@Test func anAbandonOnAnOrderWithGoodsSentDoesNothing() {
    var fixture = OrdersFixture()
    let id = fixture.world.testAddOrder(state: .accepted)
    fixture.world.orders.orders[0].delivered = 5
    fixture.world.enqueue(.abandonOrder(id))
    fixture.world.tick()
    #expect(fixture.world.order(id)?.state == .accepted)
}

// MARK: - Fulfilling and failing

@Test("scenario: fulfilling a crown order")
func scenarioFulfillingACrownOrder() {
    var fixture = OrdersFixture()
    let id = fixture.world.testAddOrder(quantity: 54, state: .accepted, reward: 540)
    fixture.setStock([.planks: 40], in: fixture.center)
    fixture.setStock([.planks: 14], in: fixture.warehouse)
    fixture.world.enqueue(.dispatchOrder(id))
    let balance = fixture.world.economy.balance
    var events = fixture.world.tick().events
    for _ in 0 ..< 40 {
        events += fixture.world.tick().events
    }
    #expect(fixture.world.order(id)?.state == .fulfilled)
    // The reward less the upkeep paid meanwhile.
    #expect(fixture.world.economy.balance > balance + 500)
    #expect(fixture.world.orders.favour.crown == 2)
    #expect(fixture.world.orders.fulfilledCount == 1)
    #expect(events.filter { $0 == .orderFulfilled(order: id, reward: 540) }.count == 1)
}

@Test("scenario: fulfilling at the deadline tick is on time")
func scenarioFulfillingAtTheDeadlineTickIsOnTime() {
    var fixture = OrdersFixture()
    fixture.setStock([.planks: 30], in: fixture.warehouse)
    let id = fixture.world.testAddOrder(quantity: 30, state: .accepted)
    guard case let .ready(plan) = fixture.world.orderDispatch(for: id) else {
        Issue.record("no plan")
        return
    }
    let arrival = fixture.world.tickCount + UInt64(plan.legs[0].path.count - 1) + 1
    fixture.world.orders.orders[0] = Order(
        id: id, template: .crownTimber, issuer: .crown, good: .planks, quantity: 30, reward: 240,
        favourGain: 2, favourLoss: 2, issuedTick: 0, offerEndsTick: 1, deadlineTick: arrival, state: .accepted
    )
    fixture.world.enqueue(.dispatchOrder(id))
    fixture.run(to: arrival)
    #expect(fixture.world.order(id)?.state == .fulfilled)
    fixture.world.tick()
    #expect(fixture.world.order(id)?.state == .fulfilled)
}

@Test("scenario: a missed deadline costs favour")
func scenarioAMissedDeadlineCostsFavour() {
    var fixture = OrdersFixture()
    fixture.setStock([.planks: 10], in: fixture.warehouse)
    let deadline = fixture.world.tickCount + 20
    let id = fixture.world.testAddOrder(state: .accepted, deadline: deadline)
    let balance = fixture.world.economy.balance
    fixture.run(to: deadline)
    #expect(fixture.world.order(id)?.state == .accepted)
    let events = fixture.world.tick().events
    #expect(fixture.world.order(id)?.state == .failed)
    #expect(fixture.world.orders.favour.crown == -2)
    #expect(fixture.world.orders.failedCount == 1)
    #expect(events.filter { $0 == .orderFailed(order: id) }.count == 1)
    #expect(fixture.stock(.planks, in: fixture.warehouse) == 10)
    // Upkeep may have been paid, but nothing was taken for the order.
    #expect(fixture.world.economy.balance <= balance)
}

@Test("scenario: favour is clamped")
func scenarioFavourIsClamped() {
    var ledger = FavourLedger()
    ledger.crown = -9
    ledger.adjust(.crown, by: -3)
    #expect(ledger.crown == -10)
    ledger.crown = 19
    ledger.adjust(.crown, by: 2)
    #expect(ledger.crown == 20)
    ledger.adjust(.rival(2), by: 4)
    #expect(ledger.value(for: .rival(2)) == 4)
    #expect(ledger.value(for: .rival(3)) == 0)
}

@Test("scenario: favour steps")
func scenarioFavourSteps() {
    #expect([5, 6, 11, 12, -4, 20].map(OrderRules.step(of:)) == [0, 1, 1, 2, 0, 2])
}

// MARK: - Events

@Test("scenario: order events are emitted once")
func scenarioOrderEventsAreEmittedOnce() {
    var fixture = OrdersFixture()
    let offered = fixture.cross(season: 4, output: [.planks: 30])
    let id = fixture.orders[0].id
    #expect(offered.filter { $0 == .orderOffered(order: id, issuer: .crown) }.count == 1)
    fixture.world.enqueue(.acceptOrder(id))
    let accepted = fixture.world.tick().events
    #expect(accepted.filter { $0 == .orderAccepted(order: id) }.count == 1)
    fixture.setStock([.planks: 40], in: fixture.center)
    fixture.setStock([.planks: 14], in: fixture.warehouse)
    fixture.world.enqueue(.dispatchOrder(id))
    var filled = fixture.world.tick().events
    filled += fixture.run(to: fixture.world.tickCount + 30)
    #expect(filled.filter { if case .orderFulfilled(id, _) = $0 { true } else { false } }.count == 1)
    let later = fixture.run(to: fixture.world.tickCount + 30)
    #expect(!later.contains { if case .orderFulfilled = $0 { true } else { false } })
    #expect(!later.contains(.orderAccepted(order: id)))
    #expect(!later.contains(.orderOffered(order: id, issuer: .crown)))
}

@Test("scenario: failing and expiring emit their events")
func scenarioFailingAndExpiringEmitTheirEvents() {
    var fixture = OrdersFixture()
    let failing = fixture.world.testAddOrder(state: .accepted, deadline: 5)
    let lapsing = fixture.world.testAddOrder()
    fixture.world.orders.orders[1] = Order(
        id: lapsing, template: .crownTimber, issuer: .crown, good: .planks, quantity: 30, reward: 240,
        favourGain: 2, favourLoss: 2, issuedTick: 0, offerEndsTick: 7, deadlineTick: 900
    )
    let events = fixture.run(to: 8)
    #expect(events.contains(.orderFailed(order: failing)))
    #expect(events.contains(.orderExpired(order: lapsing)))
}

// MARK: - Goal

@Test("scenario: orders goal counts fulfilled orders")
func scenarioOrdersGoalCountsFulfilledOrders() {
    var fixture = OrdersFixture()
    fixture.world.goals = [GoalState(goal: .orders(2))]
    fixture.world.orders.fulfilledCount = 1
    #expect(fixture.world.progress(toward: .orders(2)) == (1, 2))
    fixture.world.orders.fulfilledCount = 2
    fixture.run(to: 10)
    #expect(fixture.world.progress(toward: .orders(2)) == (2, 2))
    #expect(fixture.world.goals[0].isMet)
}

@Test("scenario: failed orders do not count")
func scenarioFailedOrdersDoNotCount() {
    var fixture = OrdersFixture()
    fixture.world.orders.fulfilledCount = 1
    fixture.world.orders.failedCount = 2
    #expect(fixture.world.progress(toward: .orders(3)) == (1, 3))
}

// MARK: - Determinism

@Test("scenario: ignored orders do not change the town")
func scenarioIgnoredOrdersDoNotChangeTheTown() {
    var with = OrdersFixture()
    var without = OrdersFixture()
    for season in 4 ... 6 {
        with.cross(season: season, output: [.planks: 30])
        without.cross(season: season, output: [.planks: 30])
        without.world.orders = OrdersState()
    }
    #expect(!with.world.orders.orders.isEmpty)
    var cleared = with.world
    cleared.orders = OrdersState()
    #expect(cleared == without.world)
}

@Test("scenario: orders are deterministic")
func scenarioOrdersAreDeterministic() {
    func play() -> World {
        var fixture = OrdersFixture()
        fixture.cross(season: 4, output: [.planks: 30])
        let id = fixture.orders[0].id
        fixture.world.enqueue(.acceptOrder(id))
        fixture.setStock([.planks: 54], in: fixture.warehouse)
        fixture.run(to: fixture.world.tickCount + 2)
        fixture.world.enqueue(.dispatchOrder(id))
        fixture.run(to: fixture.world.tickCount + 40)
        return fixture.world
    }
    #expect(play() == play())
}

@Test func theBoardListsAcceptedOrdersFirstThenOffersByDeadline() {
    var fixture = OrdersFixture()
    let late = fixture.world.testAddOrder(deadline: 900)
    let soon = fixture.world.testAddOrder(deadline: 500)
    let accepted = fixture.world.testAddOrder(state: .accepted, deadline: 2000)
    fixture.world.testAddOrder(state: .fulfilled)
    #expect(fixture.world.boardOrders.map(\.id) == [accepted, soon, late])
}

@Test func issuersKnowTheirRival() {
    #expect(OrderIssuer.rival(2).rivalID == 2)
    #expect(OrderIssuer.crown.rivalID == nil)
    #expect(OrderState.offered.isOpen && OrderState.accepted.isOpen && !OrderState.fulfilled.isOpen)
}

@Test func theShowcaseSeedPutsFourOrdersOnTheBoard() {
    var fixture = OrdersFixture()
    fixture.world.seedOrdersShowcase()
    #expect(fixture.orders.map(\.state) == [.accepted, .accepted, .offered, .offered])
    #expect(fixture.orders.map(\.issuer) == [.crown, .rival(1), .crown, .rival(1)])
    #expect(fixture.world.orders.favour.crown == 7 && fixture.world.orders.favour.value(for: .rival(1)) == 3)
    #expect(fixture.stock(.planks, in: fixture.center) == 38)
    #expect(fixture.world.acceptedOrderCount == 2)
    var bare = World.fixtureWithTerrain(width: 4, height: 4, fill: .grass, seed: 1)
    bare.testSeatRival()
    bare.rivals.append(bare.rivals[0])
    bare.seedOrdersShowcase()
    #expect(bare.orders.orders.count == 4)
}
