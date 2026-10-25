import CoreGraphics
import Foundation
import SwiftUI
import Testing
@testable import CityCore
@testable import CityUI

// platform-shells scenarios of openspec/changes/add-orders: Order board,
// Order notifications, Orders chip in the HUD, Order board layout.

// MARK: - Fixtures

private let spring1203Deadline: UInt64 = 3 * CalendarState.ticksPerYear + CalendarState.ticksPerSeason

private func order(
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
private func boardSession(_ orders: [Order], change: (inout World) -> Void = { _ in }) -> GameSession {
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

private func centerID(_ world: World) -> EntityID {
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
    #expect(chip?.badge == "1")
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

// MARK: - Layout

private struct SizeClass {
    let name: String
    let size: CGSize
    let idiom: HUDIdiom

    init(_ name: String, _ size: CGSize, _ idiom: HUDIdiom) {
        self.name = name
        self.size = size
        self.idiom = idiom
    }
}

private let sizes = [
    SizeClass("phone landscape", CGSize(width: 844, height: 390), .phone),
    SizeClass("phone portrait", CGSize(width: 390, height: 844), .phone),
    SizeClass("pad landscape", CGSize(width: 1180, height: 820), .pad),
    SizeClass("pad portrait", CGSize(width: 820, height: 1180), .pad),
    SizeClass("mac", CGSize(width: 1280, height: 800), .mac),
    SizeClass("slide over", CGSize(width: 320, height: 800), .pad),
    SizeClass("tv", CGSize(width: 1920, height: 1080), .tv)
]

@Test("scenario: board stays clear of the minimap and the build rail")
func scenarioBoardStaysClearOfTheMinimapAndTheBuildRail() {
    for sizeClass in sizes {
        let (name, size, idiom) = (sizeClass.name, sizeClass.size, sizeClass.idiom)
        let layout = HUDLayout.make(size: size, idiom: idiom)
        let insets = EdgeInsets(top: idiom == .phone ? 0 : 20, leading: 0, bottom: idiom.isTouch ? 20 : 0, trailing: 0)
        let safe = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        for showsMinimap in [true, false] {
            for showsFirstSteps in [true, false] {
                guard let board = OrderBoardLayout.frame(
                    in: size, insets: insets, layout: layout, showsMinimap: showsMinimap && idiom != .tv,
                    showsFirstSteps: showsFirstSteps
                )
                else {
                    continue
                }
                #expect(safe.contains(board), "\(name): inside the screen")
                #expect(board.width == OrderBoardLayout.width(for: layout.idiom), "\(name)")
                let top = InspectorCalloutLayout.topBarBottom(topInset: insets.top, layout: layout)
                #expect(board.minY >= top, "\(name): below the top bar")
                if showsMinimap, idiom != .tv {
                    let minimap = MinimapLayout.frame(in: size, insets: insets, layout: layout)
                    #expect(!board.intersects(minimap), "\(name): minimap")
                }
                let railWidth = layout.railInset + layout.margin
                #expect(board.minX >= railWidth, "\(name): build rail")
                if layout.placement == .bottomDock {
                    #expect(board.maxY <= size.height - insets.bottom - layout.margin - 74, "\(name): dock")
                } else {
                    #expect(
                        board.maxY <= size.height - insets.bottom - layout.margin - OrderBoardLayout.toolStripBand
                            || showsMinimap,
                        "\(name): tool strip"
                    )
                }
            }
        }
    }
}

@Test("scenario: minimap at the top right pushes the board down")
func scenarioMinimapAtTheTopRightPushesTheBoardDown() throws {
    let size = CGSize(width: 820, height: 1180)
    let layout = HUDLayout.make(size: size, idiom: .pad)
    #expect(layout.placement == .bottomDock)
    let insets = EdgeInsets()
    let minimap = MinimapLayout.frame(in: size, insets: insets, layout: layout)
    let board = try #require(OrderBoardLayout.frame(in: size, insets: insets, layout: layout, showsMinimap: true, showsFirstSteps: false))
    #expect(board.minY == minimap.maxY + MinimapLayout.gap)
    let noMap = try #require(OrderBoardLayout.frame(in: size, insets: insets, layout: layout, showsMinimap: false, showsFirstSteps: false))
    #expect(noMap.minY < board.minY)
}

@Test("scenario: opening the board collapses the first-steps card")
func scenarioOpeningTheBoardCollapsesTheFirstStepsCard() {
    let layout = HUDLayout.make(size: CGSize(width: 1280, height: 800), idiom: .mac)
    #expect(!layout.collapsesFirstSteps)
    #expect(OrderBoardLayout.collapsesFirstSteps(layout: layout, boardOpen: true))
    #expect(!OrderBoardLayout.collapsesFirstSteps(layout: layout, boardOpen: false))
    let collapsed = layout.withFirstStepsCollapsed
    #expect(collapsed.collapsesFirstSteps)
    #expect(collapsed.placement == layout.placement && collapsed.idiom == layout.idiom)
}

@Test("scenario: inspector and board coexist in regular widths")
func scenarioInspectorAndBoardCoexistInRegularWidths() {
    let size = CGSize(width: 1180, height: 820)
    let layout = HUDLayout.make(size: size, idiom: .pad)
    let insets = EdgeInsets(top: 20, leading: 0, bottom: 20, trailing: 0)
    #expect(!OrderBoardLayout.replacesInspector(layout: layout))
    let with = InspectorCalloutLayout.freeArea(
        size: size, insets: insets, layout: layout, showsMinimap: true, showsOrdersBoard: true
    )
    let without = InspectorCalloutLayout.freeArea(size: size, insets: insets, layout: layout, showsMinimap: true)
    let board = OrderBoardLayout.frame(in: size, insets: insets, layout: layout, showsMinimap: true, showsFirstSteps: false)
    #expect(with.maxX <= (board?.minX ?? 0) - MinimapLayout.gap)
    #expect(with.maxX < without.maxX)
    #expect(with.minX == without.minX)
}

@MainActor
@Test("scenario: one replaces the other in a compact width")
func scenarioOneReplacesTheOtherInACompactWidth() {
    let layout = HUDLayout.make(size: CGSize(width: 844, height: 390), idiom: .phone)
    #expect(OrderBoardLayout.replacesInspector(layout: layout))
    let session = boardSession([order(1)])
    session.ordersReplaceInspector = true
    session.toggleOrdersBoard()
    session.selectedTile = TileCoordinate(x: 3, y: 3)
    session.handleTap(at: TileCoordinate(x: 4, y: 4))
    #expect(!session.isOrdersPresented)
    #expect(session.selectedTile == TileCoordinate(x: 4, y: 4))
    session.toggleOrdersBoard()
    #expect(session.isOrdersPresented)
    #expect(session.selectedTile == nil)
    let regular = boardSession([order(1)])
    regular.selectedTile = TileCoordinate(x: 3, y: 3)
    regular.toggleOrdersBoard()
    #expect(regular.isOrdersPresented && regular.selectedTile == TileCoordinate(x: 3, y: 3))
}

@Test("scenario: board is a sheet on a phone in portrait")
func scenarioBoardIsASheetOnAPhoneInPortrait() {
    let portrait = HUDLayout.make(size: CGSize(width: 390, height: 844), idiom: .phone)
    #expect(OrderBoardLayout.presentation(for: portrait) == .sheet)
    #expect(OrderBoardLayout.frame(
        in: CGSize(width: 390, height: 844),
        insets: EdgeInsets(),
        layout: portrait,
        showsMinimap: false,
        showsFirstSteps: false
    ) == nil)
    let landscape = HUDLayout.make(size: CGSize(width: 844, height: 390), idiom: .phone)
    #expect(OrderBoardLayout.presentation(for: landscape) == .column)
    let tv = HUDLayout.make(size: CGSize(width: 1920, height: 1080), idiom: .tv)
    #expect(OrderBoardLayout.presentation(for: tv) == .column)
    #expect(OrderBoardLayout.width(for: .tv) == 520 && OrderBoardLayout.width(for: .phone) == 300)
    #expect(OrderBoardLayout.width(for: .pad) == 340 && OrderBoardLayout.width(for: .mac) == 340)
}

@Test func theColumnFitsWhereThereIsRoom() {
    for sizeClass in sizes {
        let (name, size, idiom) = (sizeClass.name, sizeClass.size, sizeClass.idiom)
        guard OrderBoardLayout.presentation(for: HUDLayout.make(size: size, idiom: idiom)) == .column else { continue }
        let layout = HUDLayout.make(size: size, idiom: idiom)
        let frame = OrderBoardLayout.frame(
            in: size, insets: EdgeInsets(), layout: layout, showsMinimap: idiom != .tv, showsFirstSteps: true
        )
        #expect(frame != nil || size.height < 500, "\(name)")
    }
}
