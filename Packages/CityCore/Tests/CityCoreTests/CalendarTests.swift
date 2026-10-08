import Foundation
import Testing
@testable import CityCore

// Scenarios from openspec/changes/add-calendar-and-events.

private func activeFixture(seed: UInt64 = 1) -> World {
    var world = World.fixtureWithTerrain(width: 8, height: 8, fill: .grass, seed: seed)
    world.calendar = CalendarState(startYear: 1200, isActive: true)
    return world
}

private func run(_ world: inout World, untilTick tick: UInt64) -> [WorldEvent] {
    var events: [WorldEvent] = []
    while world.tickCount < tick {
        events += world.tick().events
    }
    return events
}

@Test("scenario: new game starts in spring 1200")
func scenarioNewGameStartsInSpring1200() {
    let world = World.newGame()
    #expect(world.date == GameDate(year: 1200, season: .spring))
    #expect(world.calendar.isActive)
}

@Test("scenario: seasons advance every 600 ticks")
func scenarioSeasonsAdvanceEvery600Ticks() {
    var world = activeFixture()
    _ = run(&world, untilTick: 599)
    #expect(world.date == GameDate(year: 1200, season: .spring))
    _ = run(&world, untilTick: 600)
    #expect(world.date == GameDate(year: 1200, season: .summer))
}

@Test("scenario: year advances every 2400 ticks")
func scenarioYearAdvancesEvery2400Ticks() {
    var world = activeFixture()
    _ = run(&world, untilTick: 2400)
    #expect(world.date == GameDate(year: 1201, season: .spring))
}

@Test("scenario: season change emits an event")
func scenarioSeasonChangeEmitsAnEvent() {
    var world = activeFixture()
    _ = run(&world, untilTick: 599)
    let events = world.tick().events
    #expect(events.contains(.seasonChanged(.summer)))
}

/// Ticks a fresh farm cycle starting at the first winter tick and
/// returns how many ticks it took, emptying the farm's output so it
/// never stalls on a full stockpile.
private func winterCycleTicks(kind: BuildingKind, calendarActive: Bool) throws -> (ticks: Int, stalled: Bool) {
    var world = activeFixture()
    world.calendar.isActive = calendarActive
    world.enqueue(.place(kind, at: TileCoordinate(x: 2, y: 2)))
    world.tick()
    let id = try #require(world.occupiedTiles[TileCoordinate(x: 2, y: 2)])
    while world.tickCount < 1799 {
        world.tick()
        world.stockpiles[id] = Stockpile(capacity: 16)
    }
    #expect(world.buildings[id]?.state == .operational)
    world.productions[id] = ProductionProgress()
    var stalled = false
    for elapsed in 1 ... 400 {
        let events = world.tick().events
        stalled = stalled || world.productions[id]?.isStalled == true
        if events.contains(.productionCycleCompleted(producer: id, kind: kind)) {
            return (elapsed, stalled)
        }
    }
    return (-1, stalled)
}

@Test("scenario: farm takes twice as long in winter")
func scenarioFarmTakesTwiceAsLongInWinter() throws {
    let cycle = try #require(ProductionCatalog.recipe(for: .farm)).cycleTicks
    let result = try winterCycleTicks(kind: .farm, calendarActive: true)
    #expect(result.ticks == Int(cycle) * 2)
    #expect(!result.stalled)
}

@Test("scenario: sawmill ignores winter")
func scenarioSawmillIgnoresWinter() throws {
    var world = activeFixture()
    world.enqueue(.place(.sawmill, at: TileCoordinate(x: 2, y: 2)))
    world.tick()
    let id = try #require(world.occupiedTiles[TileCoordinate(x: 2, y: 2)])
    while world.tickCount < 1799 {
        world.tick()
    }
    world.stockpiles[id] = Stockpile(capacity: 16)
    world.stockpiles[id]?.deposit(.wood, amount: 8)
    world.productions[id] = ProductionProgress()
    let cycle = try #require(ProductionCatalog.recipe(for: .sawmill)).cycleTicks
    var elapsed = 0
    while elapsed < 400 {
        elapsed += 1
        if world.tick().events.contains(.productionCycleCompleted(producer: id, kind: .sawmill)) { break }
    }
    #expect(elapsed == Int(cycle))
}

@Test("scenario: inactive calendar has no winter")
func scenarioInactiveCalendarHasNoWinter() throws {
    let cycle = try #require(ProductionCatalog.recipe(for: .farm)).cycleTicks
    let result = try winterCycleTicks(kind: .farm, calendarActive: false)
    #expect(result.ticks == Int(cycle))
}

@Test("scenario: same seed and year give the same event")
func scenarioSameSeedAndYearGiveTheSameEvent() {
    for seed: UInt64 in [0, 1, 7, 42] {
        let first = activeFixture(seed: seed)
        let second = activeFixture(seed: seed)
        for year in 1201 ... 1210 {
            #expect(first.historyEvent(forYear: year) == second.historyEvent(forYear: year))
        }
    }
    let decided = (1201 ... 1240).compactMap { activeFixture(seed: 3).historyEvent(forYear: $0) }
    #expect(!decided.isEmpty)
    #expect(decided.count < 40)
}

@Test("scenario: no event in the first year")
func scenarioNoEventInTheFirstYear() {
    var world = World.newGame()
    let events = run(&world, untilTick: 2399)
    #expect(!events.contains { if case .historyEvent = $0 { true } else { false } })
}

@Test("scenario: trade caravan pays")
func scenarioTradeCaravanPays() {
    var world = activeFixture()
    let before = world.economy.balance
    world.applyHistoryEvent(.tradeCaravan)
    #expect(world.economy.balance - before == 150)
}

@Test("scenario: rats halve stored food")
func scenarioRatsHalveStoredFood() throws {
    var world = World.newGame()
    let center = try #require(world.goodsBuffers().first)
    let held = world.stockpiles[center.id]?.quantity(of: .food) ?? 0
    world.stockpiles[center.id]?.deposit(.food, amount: 9 - held)
    world.applyHistoryEvent(.ratsInTheGranary)
    #expect(world.stockpiles[center.id]?.quantity(of: .food) == 5)
}

@Test("scenario: bountiful harvest fills the stores")
func scenarioBountifulHarvestFillsTheStores() throws {
    var world = World.newGame()
    let center = try #require(world.goodsBuffers().first)
    let before = world.stockpiles[center.id]?.quantity(of: .food) ?? 0
    world.applyHistoryEvent(.bountifulHarvest)
    #expect(world.stockpiles[center.id]?.quantity(of: .food) == before + 8)
}

@Test("scenario: travelling scholar brings knowledge")
func scenarioTravellingScholarBringsKnowledge() {
    var world = World.newGame()
    let before = world.research.knowledge
    world.applyHistoryEvent(.travellingScholar)
    #expect(world.research.knowledge - before == 20)
}

@Test("scenario: events leave the world rng alone")
func scenarioEventsLeaveTheWorldRngAlone() {
    var world = activeFixture(seed: 3)
    _ = run(&world, untilTick: 2399)
    let before = world.rng
    world.tick()
    #expect(world.rng == before)
}
