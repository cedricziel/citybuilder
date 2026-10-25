import Foundation
import Testing
@testable import CityCore
@testable import CityUI

// Scenarios from openspec/changes/add-statistics-screen (statistics /
// The Statistics sheet): the series the sheet draws.

private let calendar = CalendarState(startYear: 1200, isActive: true)

private func season(
    _ number: Int, goods: [Good: GoodFlow] = [:], producers: [BuildingKind: ProducerActivity] = [:]
) -> SeasonStatistics {
    var record = SeasonStatistics()
    record.season = number
    record.storeCapacity = 200
    record.goods = goods
    record.producers = producers
    return record
}

private func flow(made: Int = 0, used: Int = 0, sold: Int = 0, bought: Int = 0, stored: Int = 0, stuck: Int = 0) -> GoodFlow {
    var flow = GoodFlow()
    flow.made = made
    flow.usedByProduction = used
    flow.sold = sold
    flow.bought = bought
    flow.stored = stored
    flow.stuckSamples = stuck
    return flow
}

private func activity(working: Int = 0, waiting: Int = 0, stuck: Int = 0, blocked: Int = 0) -> ProducerActivity {
    var activity = ProducerActivity()
    activity.working = working
    activity.waiting = waiting
    activity.stuck = stuck
    activity.blocked = blocked
    return activity
}

@Test("scenario: empty history")
func scenarioEmptyHistory() {
    let model = StatisticsModel(seasons: [], calendar: calendar)
    #expect(model.isEmpty)
    #expect(model.goods.isEmpty)
    #expect(model.standings.isEmpty)
    #expect(model.tabs == [.goods, .money, .people])
}

@Test("scenario: rivals tab is conditional")
func scenarioRivalsTabIsConditional() {
    let model = StatisticsModel(seasons: [], calendar: calendar, rivals: [1: ("Ravenmoor", "#B03A2E")])
    #expect(model.tabs == [.goods, .money, .people, .rivals])
    #expect(StatisticsModel.Tab.rivals.title == "Rivals")
}

@Test("goods list: only goods with numbers, in catalog order, with net and stopped now")
func goodsListHasOnlyGoodsWithNumbers() {
    let seasons = [
        season(0, goods: [.bread: flow(made: 6, used: 2), .wood: flow(made: 4)]),
        season(1, goods: [.bread: flow(made: 10, used: 4, stuck: 3), .wood: flow(made: 4, used: 4)])
    ]
    let model = StatisticsModel(seasons: seasons, calendar: calendar, stuckNow: [.bread: 2])
    #expect(model.goods.map(\.good) == [.wood, .bread])
    let bread = model.goods[1]
    #expect(bread.name == "Bread")
    #expect(bread.net == 6)
    #expect(bread.stoppedNow == 2)
    #expect(bread.made.map(\.value) == [6, 10])
    #expect(bread.used.map(\.value) == [2, 4])
    #expect(model.goods[0].stoppedNow == 0)
    #expect(model.stoppedProducersNow == 2)
}

@Test("scenario: a stopped producer is shown")
func scenarioAStoppedProducerIsShown() {
    let seasons = [
        season(0, goods: [.bread: flow(made: 10, stored: 40)], producers: [.bakery: activity(working: 40, waiting: 20)]),
        season(
            1,
            goods: [.bread: flow(made: 8, sold: 2, bought: 1, stored: 80, stuck: 30)],
            producers: [.bakery: activity(working: 10, waiting: 5, stuck: 30, blocked: 15)]
        )
    ]
    let detail = StatisticsModel(seasons: seasons, calendar: calendar).detail(of: .bread)
    #expect(detail.stuckShare == [0, 0.5])
    #expect(detail.latestSold == 2)
    #expect(detail.latestBought == 1)
    #expect(detail.latestStored == 80)
    #expect(detail.stored.map(\.value) == [40, 80])
    #expect(detail.storeCap == 200)
    let bakery = detail.producers.first
    #expect(bakery?.name == "Bakery")
    #expect(bakery?.stuck == 0.5)
    #expect(bakery?.working == 1.0 / 6)
    #expect(bakery?.waiting == 1.0 / 12)
    #expect(bakery?.blocked == 0.25)
}

@Test("scenario: nothing stuck, nothing shown")
func scenarioNothingStuckNothingShown() {
    let seasons = [season(0, goods: [.bread: flow(made: 5)])]
    let model = StatisticsModel(seasons: seasons, calendar: calendar)
    #expect(model.stoppedProducersNow == 0)
    #expect(model.detail(of: .bread).stuckShare == [0])
    #expect(model.detail(of: .bread).producers.isEmpty)
}

@Test("season labels follow the calendar")
func seasonLabelsFollowTheCalendar() {
    let model = StatisticsModel(seasons: [season(0), season(5)], calendar: calendar)
    #expect(model.title(ofSeason: 0) == "Spring 1200")
    #expect(model.title(ofSeason: 5) == "Summer 1201")
    #expect(model.axisLabel(ofSeason: 4) == "1201")
    #expect(model.axisLabel(ofSeason: 5) == "")
}

@Test("money series: income above the axis, spending below")
func moneySeries() {
    var first = season(0)
    first.money.tax = 8
    first.money.tradeIncome = 4
    first.money.upkeep = 3
    first.money.tradeSpending = 2
    first.money.balance = 1050
    let model = StatisticsModel(seasons: [first], calendar: calendar)
    #expect(model.income.map(\.name) == ["Tax", "Trade"])
    #expect(model.income.map { $0.points[0].value } == [8, 4])
    #expect(model.spending.map { $0.points[0].value } == [-3, -2])
    #expect(model.balance.map(\.value) == [1050])
}

@Test("people series: tiers never reached are left out")
func peopleSeries() {
    var first = season(0)
    first.residents = [.peasants: 6]
    var second = season(1)
    second.residents = [.peasants: 8, .citizens: 3]
    let model = StatisticsModel(seasons: [first, second], calendar: calendar)
    #expect(model.tiers.map(\.name) == ["Peasants", "Citizens"])
    #expect(model.tiers[1].points.map(\.value) == [0, 3])
}

@Test("rivals: lines and standings")
func rivalsLinesAndStandings() {
    var first = season(0)
    first.residents = [.peasants: 6, .citizens: 2]
    first.money.balance = 1950
    first.age = .renaissance
    first.rivals = [
        RivalStatistics(id: 2, residents: 9, age: .medieval, treasury: 840),
        RivalStatistics(id: 1, residents: 30, age: .medieval, treasury: 1120)
    ]
    let model = StatisticsModel(
        seasons: [first], calendar: calendar,
        rivals: [1: ("Ravenmoor", "#B03A2E"), 2: ("Saltwick", "#2E6DB4")],
        locale: Locale(identifier: "en_US")
    )
    #expect(model.residentLines.map(\.name) == ["You", "Ravenmoor", "Saltwick"])
    #expect(model.residentLines.map { $0.points[0].value } == [8, 30, 9])
    #expect(model.residentLineColours == [RivalColour.playerHex, "#B03A2E", "#2E6DB4"])
    let rows = model.standings
    #expect(rows.map(\.name) == ["You", "Saltwick", "Ravenmoor"])
    #expect(rows[0].residents == 8)
    #expect(rows[0].age == Age.renaissance.displayName)
    #expect(rows[0].wealth == "$1,950")
    #expect(rows[2].wealth == "$1,120")
}

@Test("a model built from a world reads its history, calendar and stuck producers")
func modelFromWorld() {
    var world = World.fixtureWithTerrain(width: 8, height: 8, fill: .grass, seed: 1)
    for _ in 0 ..< Int(CalendarState.ticksPerSeason) {
        world.tick()
    }
    let model = StatisticsModel(world: world, locale: Locale(identifier: "en_US"))
    #expect(!model.isEmpty)
    #expect(model.balance.map(\.value) == [Int(world.economy.balance)])
    #expect(model.stoppedProducersNow == 0)
    #expect(model.tabs == [.goods, .money, .people])
}

@Test("the Goods tab opens on a stopped good, else the busiest")
func defaultGoodIsStoppedThenBusiest() {
    let seasons = [season(0, goods: [.wood: flow(made: 2), .bread: flow(made: 9, used: 3), .food: flow(made: 1)])]
    #expect(StatisticsModel(seasons: seasons, calendar: calendar).defaultGood == .bread)
    #expect(StatisticsModel(seasons: seasons, calendar: calendar, stuckNow: [.food: 1]).defaultGood == .food)
    #expect(StatisticsModel(seasons: [], calendar: calendar).defaultGood == nil)
}

@Test("scenario: the sheet does not change the world")
@MainActor
func scenarioTheSheetDoesNotChangeTheWorld() {
    let session = GameSession(world: World.newGame(layout: .singleIsland, seed: 3))
    let before = session.world
    session.isStatisticsPresented = true
    for tab in StatisticsModel.Tab.allCases {
        session.statisticsTab = tab
        let model = StatisticsModel(world: session.world)
        _ = model.goods
        _ = model.standings
        _ = model.tiers
    }
    session.isStatisticsPresented = false
    #expect(session.world.pendingCommands.isEmpty)
    #expect(session.world == before)
}
