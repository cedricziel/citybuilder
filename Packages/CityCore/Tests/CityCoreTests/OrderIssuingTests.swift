import Foundation
import Testing
@testable import CityCore

// Scenarios from openspec/changes/add-orders (orders / The crown issues
// orders on a schedule, Rivals issue orders, Order size follows the town's
// output, The board holds offers that lapse).

// MARK: - Templates

@Test("scenario: built-in order templates load")
func scenarioBuiltInOrderTemplatesLoad() {
    let crown = OrderTemplate.allCases.filter { $0.issuer == .crown }
    let rival = OrderTemplate.allCases.filter { $0.issuer == .rival }
    #expect(crown.count == 6)
    #expect(rival.count == 5)
    #expect(Age.allCases.map(\.orderEvery) == [4, 4, 3, 2, 2])
    #expect(OrderTemplate.crownTimber.good == .planks)
    #expect(OrderTemplate.crownTimber.sizePercent == 90)
    for template in OrderTemplate.allCases {
        let titled: Bool = !template.title.isEmpty
        let short: Bool = template.text.count <= 100
        let window: Bool = (1 ... 8).contains(template.seasons)
        let size: Bool = (1 ... 300).contains(template.sizePercent)
        let bounds: Bool = template.minUnits >= 1 && template.minUnits <= template.maxUnits
        let rewards: Bool = template.rewardPercent >= 0 && template.favourGain >= 0 && template.favourLoss >= 0
        #expect(titled, "\(template)")
        #expect(short, "\(template)")
        #expect(window, "\(template)")
        #expect(size, "\(template)")
        #expect(bounds, "\(template)")
        #expect(rewards, "\(template)")
        #expect(template.good.basePrice > 0, "\(template)")
    }
    #expect(OrderTemplate.crownBread.minAge == .medieval)
    #expect(OrderTemplate.crownTimber.minAge == nil)
}

// MARK: - The crown's schedule

@Test("scenario: the crown's first order comes in year 2")
func scenarioTheCrownsFirstOrderComesInYear2() {
    var fixture = OrdersFixture()
    fixture.run(to: 2398)
    fixture.seedOutput([.planks: 30])
    fixture.run(to: 2399)
    #expect(fixture.orders.isEmpty)
    let events = fixture.run(to: 2400)
    #expect(fixture.orders.count == 1)
    #expect(fixture.orders.first?.issuer == .crown)
    #expect(fixture.orders.first?.state == .offered)
    #expect(events.contains(.orderOffered(order: 1, issuer: .crown)))
}

@Test("scenario: the crown's cadence follows the age")
func scenarioTheCrownsCadenceFollowsTheAge() {
    var fixture = OrdersFixture(age: .renaissance)
    #expect(fixture.issueSeasons(4 ... 10) == [4, 7, 10])
}

@Test("scenario: difficulty scales the cadence")
func scenarioDifficultyScalesTheCadence() {
    var hard = OrdersFixture(difficulty: .hard)
    #expect(hard.issueSeasons(4 ... 10) == [4, 7, 10])
    var easy = OrdersFixture(difficulty: .easy)
    #expect(easy.issueSeasons(4 ... 10) == [4, 10])
}

@Test("scenario: no order is issued when the town makes nothing")
func scenarioNoOrderIsIssuedWhenTheTownMakesNothing() {
    var fixture = OrdersFixture()
    fixture.run(to: 2400)
    #expect(fixture.orders.isEmpty)
}

@Test("scenario: a full board skips an issue")
func scenarioAFullBoardSkipsAnIssue() {
    var fixture = OrdersFixture()
    for _ in 0 ..< 3 {
        fixture.world.testAddOrder(good: .wood)
    }
    fixture.cross(season: 4, output: [.planks: 30])
    #expect(fixture.orders.count == 3)
}

@Test("scenario: a game without a calendar has no orders")
func scenarioAGameWithoutACalendarHasNoOrders() {
    var fixture = OrdersFixture(calendarOn: false)
    fixture.run(to: 2398)
    fixture.seedOutput([.planks: 30])
    fixture.run(to: 4900)
    #expect(fixture.world.orders == OrdersState())
}

@Test("scenario: no orders after the game is over")
func scenarioNoOrdersAfterTheGameIsOver() {
    var fixture = OrdersFixture()
    fixture.world.economy.gameOver = true
    fixture.cross(season: 4, output: [.planks: 30])
    #expect(fixture.orders.isEmpty)
    let id = fixture.world.testAddOrder(state: .accepted)
    fixture.world.orders.shipments = [OrderShipment(
        id: EntityID(raw: 500), order: id, good: .planks, amount: 5,
        path: [TileCoordinate(x: 13, y: 12), TileCoordinate(x: 13, y: 13)], from: fixture.warehouse, to: fixture.center
    )]
    fixture.world.tick()
    #expect(fixture.world.orders.shipments.first?.pathIndex == 0)
}

@Test("scenario: the crown varies its goods")
func scenarioTheCrownVariesItsGoods() {
    var fixture = OrdersFixture()
    fixture.world.testAddOrder(good: .planks, state: .expired)
    fixture.cross(season: 4, output: [.planks: 30, .wood: 60])
    let issued = fixture.orders.filter { $0.state == .offered }
    #expect(issued.count == 1)
    #expect(issued.first?.good == .wood)
}

@Test func theCrownIssuesTheOnlyEligibleGoodAgain() {
    var fixture = OrdersFixture()
    fixture.world.testAddOrder(good: .planks, state: .expired)
    fixture.cross(season: 4, output: [.planks: 30])
    #expect(fixture.orders.first { $0.state == .offered }?.good == .planks)
}

@Test func aTemplateWaitsForItsAge() {
    var fixture = OrdersFixture(age: .antiquity)
    fixture.cross(season: 4, output: [.bread: 40])
    #expect(fixture.orders.isEmpty)
    var medieval = OrdersFixture(age: .medieval)
    medieval.cross(season: 4, output: [.bread: 40])
    #expect(medieval.orders.first?.good == .bread)
}

// MARK: - Rivals

private func rivalFixture(treasury: Int64 = 1000, stock: [Good: Int] = [.planks: 6]) -> TradeFixture {
    var fixture = TradeFixture(treasury: treasury)
    fixture.world.calendar = CalendarState(startYear: 1200, isActive: true)
    fixture.setStock(stock)
    return fixture
}

private func cross(_ fixture: inout TradeFixture, season: Int, output: [Good: Int] = [.planks: 30]) {
    let boundary = UInt64(season) * CalendarState.ticksPerSeason
    while fixture.world.tickCount < boundary - 1 {
        fixture.world.tick()
    }
    fixture.world.statistics.seasons = (0 ..< 4).map { index in
        var record = SeasonStatistics()
        record.season = index
        for (good, made) in output {
            record.goods[good] = GoodFlow.made(made)
        }
        return record
    }
    fixture.world.tick()
}

@Test("scenario: a short rival posts an order")
func scenarioAShortRivalPostsAnOrder() {
    var fixture = rivalFixture()
    cross(&fixture, season: 5)
    let order = fixture.world.orders.orders.first
    #expect(order?.issuer == .rival(1))
    #expect(order?.good == .planks)
    #expect(order?.state == .offered)
}

@Test("scenario: a rival with no shortage posts nothing")
func scenarioARivalWithNoShortagePostsNothing() {
    var fixture = rivalFixture(stock: [.wood: 20, .planks: 20, .food: 20, .bread: 20, .tools: 20])
    cross(&fixture, season: 5, output: [.planks: 30, .wood: 30, .food: 30, .bread: 30, .tools: 30])
    #expect(fixture.world.orders.orders.isEmpty)
}

@Test("scenario: a rival has one open order at a time")
func scenarioARivalHasOneOpenOrderAtATime() {
    var fixture = rivalFixture()
    fixture.world.testAddOrder(.rival(1), good: .planks, state: .accepted, deadline: 99999)
    cross(&fixture, season: 5)
    #expect(fixture.world.orders.orders.count == 1)
}

@Test("scenario: a rival that cannot pay posts nothing")
func scenarioARivalThatCannotPayPostsNothing() {
    var fixture = rivalFixture(treasury: 20)
    cross(&fixture, season: 5)
    #expect(fixture.world.orders.orders.isEmpty)
}

@Test func aRivalWaitsForItsSlot() {
    var fixture = rivalFixture()
    cross(&fixture, season: 4)
    #expect(fixture.world.orders.orders.isEmpty)
}

// MARK: - Size

@Test("scenario: size follows recent output")
func scenarioSizeFollowsRecentOutput() {
    var fixture = OrdersFixture()
    fixture.cross(season: 4, output: [.planks: 30])
    let order = fixture.orders.first
    #expect(order?.quantity == 54)
    #expect(order?.reward == 540)
    #expect(order?.template == .crownTimber)
    let deadline: UInt64 = 3600
    let offerEnds: UInt64 = 3000
    #expect(order?.deadlineTick == deadline)
    #expect(order?.offerEndsTick == offerEnds)
}

@Test("scenario: size is capped by the stores")
func scenarioSizeIsCappedByTheStores() {
    var fixture = OrdersFixture()
    fixture.world.stockpiles[fixture.warehouse] = Stockpile(perGood: 20)
    fixture.cross(season: 4, output: [.planks: 30])
    #expect(fixture.orders.first?.quantity == 45)
}

@Test("scenario: size is capped by the template")
func scenarioSizeIsCappedByTheTemplate() {
    var fixture = OrdersFixture()
    fixture.cross(season: 4, output: [.planks: 100])
    #expect(fixture.orders.first?.quantity == 80)
}

@Test("scenario: difficulty scales the size and the time")
func scenarioDifficultyScalesTheSizeAndTheTime() {
    var hard = OrdersFixture(difficulty: .hard)
    hard.cross(season: 4, output: [.planks: 30])
    #expect(hard.orders.first?.quantity == 64)
    let hardDeadline: UInt64 = 3600
    #expect(hard.orders.first?.deadlineTick == hardDeadline)
    var easy = OrdersFixture(difficulty: .easy)
    easy.cross(season: 4, output: [.planks: 30])
    #expect(easy.orders.first?.quantity == 43)
    let easyDeadline: UInt64 = 4200
    #expect(easy.orders.first?.deadlineTick == easyDeadline)
}

@Test("scenario: too little output is not asked for")
func scenarioTooLittleOutputIsNotAskedFor() {
    var fixture = OrdersFixture()
    fixture.cross(season: 4, output: [.planks: 3])
    #expect(fixture.orders.isEmpty)
}

@Test func storesOutsideTheRoadNetworkDoNotCountForTheCrown() {
    var fixture = OrdersFixture()
    fixture.world.stockpiles[fixture.warehouse] = Stockpile(perGood: 0)
    fixture.world.testPlace(.warehouse, at: TileCoordinate(x: 30, y: 30), owner: .player)
    fixture.cross(season: 4, output: [.planks: 100])
    // Only the town center's 40 count: 75% of 40.
    #expect(fixture.orders.first?.quantity == 30)
}

// MARK: - The board

@Test("scenario: an offer lapses at the end of its season")
func scenarioAnOfferLapsesAtTheEndOfItsSeason() {
    var fixture = OrdersFixture()
    fixture.cross(season: 4, output: [.planks: 30])
    let id = fixture.orders.first?.id ?? 0
    fixture.run(to: 2999)
    #expect(fixture.world.order(id)?.state == .offered)
    let events = fixture.run(to: 3000)
    #expect(fixture.world.order(id)?.state == .expired)
    #expect(events.contains(.orderExpired(order: id)))
    #expect(fixture.world.orders.favour == FavourLedger())
}

@Test func closedOrdersAreTrimmed() {
    var fixture = OrdersFixture()
    for _ in 0 ..< 20 {
        fixture.world.testAddOrder(state: .fulfilled)
    }
    fixture.world.testAddOrder(state: .accepted)
    fixture.run(to: 1)
    #expect(fixture.orders.filter { $0.state == .fulfilled }.count == OrderRules.closedOrdersKept)
    #expect(fixture.orders.contains { $0.state == .accepted })
}
