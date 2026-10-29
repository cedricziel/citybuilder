import CoreGraphics
import Foundation
import SwiftUI
import Testing
@testable import CityCore
@testable import CityUI

// platform-shells scenarios of openspec/changes/add-orders: Order board,
// Order notifications, Orders chip in the HUD, Order board layout.

// MARK: - Fixtures

let spring1203Deadline: UInt64 = 3 * CalendarState.ticksPerYear + CalendarState.ticksPerSeason

func order(
    _ id: OrderID, issuer: OrderIssuer = .crown, good: Good = .planks, quantity: Int = 54, reward: Int64 = 540,
    state: OrderState = .offered, delivered: Int = 0, deadline: UInt64 = spring1203Deadline,
    template: OrderTemplate = .crownTimber, offerEnds: UInt64 = 10 * CalendarState.ticksPerSeason
) -> Order {
    Order(
        id: id, template: template, issuer: issuer, good: good, quantity: quantity, reward: reward, favourGain: 2,
        favourLoss: 2, issuedTick: 0, offerEndsTick: offerEnds, deadlineTick: deadline, state: state, delivered: delivered
    )
}

/// A single-island Normal game with the given orders on the board.
@MainActor
func boardSession(_ orders: [Order], change: (inout World) -> Void = { _ in }) -> GameSession {
    var world = World.newGame()
    world.orders.orders = orders
    world.orders.nextOrderRaw = (orders.map(\.id).max() ?? 0) + 1
    change(&world)
    return GameSession(world: world)
}

private extension World {
    /// Makes the town center hold exactly `amount` planks.
    mutating func testSetPlanks(_ amount: Int) {
        let center = centerID(self)
        let held = stockpiles[center]?.quantity(of: .planks) ?? 0
        stockpiles[center]?.withdraw(.planks, amount: held)
        stockpiles[center]?.deposit(.planks, amount: amount)
    }
}

func centerID(_ world: World) -> EntityID {
    world.goodsBuffers(of: .player).first { $0.kind == .townCenter }?.id ?? EntityID(raw: 0)
}

// MARK: - Order board

@MainActor
@Test("scenario: board lists accepted orders first")
func scenarioBoardListsAcceptedOrdersFirst() {
    let session = boardSession([
        order(1, state: .offered, deadline: 900),
        order(2, state: .offered, deadline: 700),
        order(3, state: .accepted, deadline: 2000)
    ])
    #expect(session.ordersBoard.cards.map(\.id) == [3, 2, 1])
    #expect(session.ordersBoard.cards.map(\.isAccepted) == [true, false, false])
}

@MainActor
@Test("scenario: offers appear in deadline order")
func scenarioOffersAppearInDeadlineOrder() {
    let season = CalendarState.ticksPerSeason
    let session = boardSession([
        order(1, deadline: 3 * season), order(2, deadline: 1 * season), order(3, deadline: 2 * season)
    ])
    #expect(session.ordersBoard.cards.map(\.id) == [2, 3, 1])
}

@MainActor
@Test("scenario: a card shows what the order needs")
func scenarioACardShowsWhatTheOrderNeeds() throws {
    let session = boardSession([order(1)])
    let card = try #require(session.ordersBoard.cards.first)
    #expect(card.issuerName == "The Crown")
    #expect(card.title == "Timber for the fleet")
    #expect(card.goodName == "Planks")
    #expect(card.quantity == 54)
    #expect(card.deadline == "by Spring 1203")
    #expect(card.reward == "$540")
    #expect(card.favour == "+2 favour")
    #expect(card.status == "Offer ends with summer")
    #expect(!card.isAccepted && !card.byShip)
}

@MainActor
@Test func aRivalsCardNamesTheRivalAndTheShip() throws {
    let session = boardSession([order(1, issuer: .rival(1), good: .bread, quantity: 24, state: .accepted, delivered: 8)]) { world in
        world.rivals = [RivalTown(
            id: 1, name: "Ravenmoor", islandID: 1, culture: .mediterranean, colour: .crimson,
            age: world.age, treasury: 100, townCenterID: EntityID(raw: 9), ai: RivalAIState()
        )]
    }
    let card = try #require(session.ordersBoard.cards.first)
    #expect(card.issuerName == "Ravenmoor")
    #expect(card.issuerColourHex == RivalColour.crimson.hex)
    #expect(card.byShip)
    #expect(card.status == "Delivered 8 of 24 by ship")
    #expect(abs(card.progress - 1.0 / 3.0) < 0.001)
    #expect(!card.canSend)
    #expect(!card.canAbandon)
}

@MainActor
@Test("scenario: accept and decline enqueue commands")
func scenarioAcceptAndDeclineEnqueueCommands() {
    let session = boardSession([order(1), order(2)])
    session.acceptOrder(1)
    session.declineOrder(2)
    #expect(session.world.pendingCommands == [.acceptOrder(1), .declineOrder(2)])
}

@MainActor
@Test("scenario: accept is disabled at the open limit")
func scenarioAcceptIsDisabledAtTheOpenLimit() {
    let session = boardSession([order(1, state: .accepted), order(2, state: .accepted), order(3), order(4)])
    let offers = session.ordersBoard.cards.filter { !$0.isAccepted }
    #expect(offers.count == 2)
    #expect(offers.allSatisfy { !$0.canAccept })
    let open = boardSession([order(1, state: .accepted), order(3)])
    #expect(open.ordersBoard.cards.first { !$0.isAccepted }?.canAccept == true)
}

@MainActor
@Test("scenario: send is enabled when the stores hold enough")
func scenarioSendIsEnabledWhenTheStoresHoldEnough() throws {
    let session = boardSession([order(1, quantity: 30, state: .accepted)]) { world in
        // The new game's starter planks count too: stock exactly 29.
        world.testSetPlanks(29)
    }
    var card = try #require(session.ordersBoard.cards.first)
    #expect(!card.canSend)
    #expect(card.status == "In stores 29 of 30")
    session.sendOrder(1)
    session.world.stockpiles[centerID(session.world)]?.deposit(.planks, amount: 1)
    card = try #require(session.ordersBoard.cards.first)
    #expect(card.canSend)
    #expect(card.status == "In stores 30 of 30")
    session.world.pendingCommands.removeAll()
    session.sendOrder(1)
    #expect(session.world.pendingCommands == [.dispatchOrder(1)])
}

@MainActor
@Test func anOrderOnTheRoadShowsWhatIsSentAndAbandonGoesAway() throws {
    let session = boardSession([order(1, quantity: 30, state: .accepted, delivered: 15)]) { world in
        world.orders.shipments = [OrderShipment(
            id: EntityID(raw: 90), order: 1, good: .planks, amount: 15,
            path: [TileCoordinate(x: 1, y: 1), TileCoordinate(x: 1, y: 2)], from: EntityID(raw: 1), to: EntityID(raw: 2)
        )]
    }
    let card = try #require(session.ordersBoard.cards.first)
    #expect(card.status == "Delivered 15 of 30, 15 on the road")
    #expect(!card.canSend && !card.canAbandon)
}

@MainActor
@Test func abandonIsOfferedBeforeAnythingIsSent() {
    let session = boardSession([order(1, quantity: 30, state: .accepted)])
    #expect(session.ordersBoard.cards.first?.canAbandon == true)
    session.abandonOrder(1)
    #expect(session.world.pendingCommands == [.abandonOrder(1)])
}

@MainActor
@Test func anOrderWithoutATownCenterSaysSo() {
    let session = boardSession([order(1, quantity: 30, state: .accepted)]) { world in
        world.buildings[centerID(world)]?.state = .constructing
    }
    #expect(session.ordersBoard.cards.first?.status == "No town center to send to")
    #expect(session.ordersBoard.cards.first?.canSend == false)
}

@MainActor
@Test("scenario: favour readout lists perks")
func scenarioFavourReadoutListsPerks() throws {
    let session = boardSession([]) { world in
        world.orders.favour.adjust(.crown, by: 6)
    }
    let crown = try #require(session.ordersBoard.favour.first)
    #expect(crown.name == "The Crown")
    #expect(crown.value == 6)
    #expect(crown.step == 1)
    #expect(crown.perk == "Research costs 3% less")
    let fresh = boardSession([])
    #expect(fresh.ordersBoard.favour.first?.perk == "Next step at 6: research costs 3% less")
}

@MainActor
@Test func rivalsGetTheirOwnFavourRows() {
    let session = boardSession([]) { world in
        world.rivals = [RivalTown(
            id: 2, name: "Saltmere", islandID: 1, culture: .mediterranean, colour: .azure,
            age: world.age, treasury: 100, townCenterID: EntityID(raw: 9), ai: RivalAIState()
        )]
        world.orders.favour.adjust(.rival(2), by: 12)
    }
    let rows = session.ordersBoard.favour
    #expect(rows.map(\.name) == ["The Crown", "Saltmere"])
    #expect(rows[1].step == 2)
    #expect(rows[1].perk == "Prices 10% better")
    #expect(rows[1].colourHex == RivalColour.azure.hex)
}

@MainActor
@Test("scenario: the board locks after game over")
func scenarioTheBoardLocksAfterGameOver() {
    let session = boardSession([order(1, quantity: 30, state: .accepted), order(2)]) { world in
        world.economy.gameOver = true
        world.testSetPlanks(30)
    }
    let board = session.ordersBoard
    #expect(board.isLocked)
    #expect(board.cards.allSatisfy { !$0.canAccept && !$0.canSend && !$0.canAbandon })
    session.acceptOrder(2)
    #expect(session.world.pendingCommands.isEmpty)
}

// MARK: - Chip

@MainActor
@Test("scenario: chip counts accepted orders")
func scenarioChipCountsAcceptedOrders() {
    let session = boardSession([order(1, state: .accepted), order(2)])
    let chip = session.ordersChip
    #expect(chip?.label == "Orders 1/2")
    #expect(chip?.hasOffer == true)
    let none = boardSession([order(1, state: .accepted), order(2, state: .accepted)])
    #expect(none.ordersChip?.hasOffer == false)
}

@MainActor
@Test("scenario: chip is hidden without a calendar")
func scenarioChipIsHiddenWithoutACalendar() {
    let session = boardSession([]) { world in
        world.calendar = CalendarState(startYear: 1200, isActive: false)
    }
    #expect(session.ordersChip == nil)
}

@MainActor
@Test("scenario: chip opens the board")
func scenarioChipOpensTheBoard() {
    let session = boardSession([order(1)])
    #expect(!session.isOrdersPresented)
    session.toggleOrdersBoard()
    #expect(session.isOrdersPresented)
    session.toggleOrdersBoard()
    #expect(!session.isOrdersPresented)
}

// MARK: - Notifications

@MainActor
@Test("scenario: an offer raises a banner")
func scenarioAnOfferRaisesABanner() throws {
    let session = boardSession([order(1)])
    session.noteBannerEvents(in: [.orderOffered(order: 1, issuer: .crown)])
    let banner = try #require(session.banner)
    #expect(banner.title == "The Crown orders 54 planks")
    #expect(banner.description == "Timber for the fleet, by Spring 1203. Pays $540 and 2 favour. Open the board to accept.")
}

@MainActor
@Test("scenario: a fulfilled order raises a banner")
func scenarioAFulfilledOrderRaisesABanner() throws {
    let session = boardSession([order(1, state: .fulfilled)]) { world in
        world.orders.favour.adjust(.crown, by: 9)
    }
    session.noteBannerEvents(in: [.orderFulfilled(order: 1, reward: 540)])
    let banner = try #require(session.banner)
    #expect(banner.title == "Order filled: 54 planks")
    #expect(banner.description == "The Crown pays $540, and its favour rises to 9.")
}

@MainActor
@Test("scenario: a missed order raises a banner")
func scenarioAMissedOrderRaisesABanner() throws {
    let session = boardSession([order(1, issuer: .rival(1), good: .bread, quantity: 24, state: .failed, delivered: 8)]) { world in
        world.rivals = [RivalTown(
            id: 1, name: "Ravenmoor", islandID: 1, culture: .mediterranean, colour: .crimson,
            age: world.age, treasury: 100, townCenterID: EntityID(raw: 9), ai: RivalAIState()
        )]
    }
    session.noteBannerEvents(in: [.orderFailed(order: 1)])
    let banner = try #require(session.banner)
    #expect(banner.title == "Order missed: bread for Ravenmoor")
    #expect(banner.description == "The deadline passed with 8 of 24 delivered. Ravenmoor's favour falls by 2.")
}

@MainActor
@Test func aLapsedOfferIsAQuietNotice() {
    let session = boardSession([order(1, state: .expired)])
    session.noteBannerEvents(in: [.orderExpired(order: 1)])
    #expect(session.banner?.title == "An offer from The Crown lapsed")
}

@MainActor
@Test func orderBannersQueueBehindGameOver() {
    let session = boardSession([order(1)]) { world in
        world.economy.gameOver = true
    }
    session.noteBannerEvents(in: [.orderOffered(order: 1, issuer: .crown)])
    #expect(session.banner == GameSession.gameOverBanner)
}

@MainActor
@Test func acceptingAnOrderThatIsGoneShowsNothing() {
    let session = boardSession([])
    session.noteBannerEvents(in: [
        .orderOffered(order: 7, issuer: .crown),
        .orderFulfilled(order: 7, reward: 1),
        .orderFailed(order: 7),
        .orderExpired(order: 7),
        .orderAccepted(order: 7)
    ])
    #expect(session.banner == nil)
}
