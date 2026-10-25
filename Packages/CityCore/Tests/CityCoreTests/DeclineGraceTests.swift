import Foundation
import Testing
@testable import CityCore

// Scenarios from openspec/changes/decline-grace: population-and-needs /
// Houses decline only after a grace period, and rendering-2_5d /
// A house running short shows the short icon before it declines.

/// Fills the town center with every merchant need except what `missing`
/// names, so the house draws everything else in full.
func restock(_ fixture: inout HouseFixture, missing: Set<Good>) {
    var stock = Stockpile(capacity: 400)
    for good in [Good.food, .planks, .bread, .tools, .cloth, .beer] where !missing.contains(good) {
        _ = stock.deposit(good, amount: 40)
    }
    fixture.world.stockpiles[fixture.center] = stock
}

/// Ticks `ticks` times, restocking before each so the missing goods stay missing.
private func run(_ fixture: inout HouseFixture, ticks: Int, missing: Set<Good> = [.tools]) {
    for _ in 0 ..< ticks {
        restock(&fixture, missing: missing)
        fixture.world.tick()
    }
}

/// One consumption interval: the house eats on the first tick and then waits out the other 99.
private func interval(_ fixture: inout HouseFixture, missing: Set<Good> = [.tools]) {
    run(&fixture, ticks: Int(HousePopulation.consumptionIntervalTicks), missing: missing)
}

func merchantHouse(residents: UInt32 = 8) throws -> HouseFixture {
    var fixture = try houseNextToTownCenter(food: 0, planks: 0, residents: residents, tier: .merchants)
    fixture.world.difficulty = .normal
    return fixture
}

func grace(_ fixture: HouseFixture) -> Int {
    fixture.world.difficulty.declineGraceIntervals(base: HouseTier.merchants.declineGrace)
}

private func pop(_ fixture: HouseFixture) throws -> HousePopulation {
    try #require(fixture.world.populations[fixture.house])
}

@Test("scenario: a short need does not decline a house within its grace")
func scenarioAShortNeedDoesNotDeclineAHouseWithinItsGrace() throws {
    var fixture = try merchantHouse()
    let waiting = grace(fixture) - 1
    try #require(waiting >= 1)
    for _ in 0 ..< waiting {
        interval(&fixture)
    }
    let house = try pop(fixture)
    #expect(house.shortIntervals(of: .tools) == waiting)
    #expect(house.population == 8)
    #expect(house.tier == .merchants)
}

@Test("scenario: a house declines once the grace has run out")
func scenarioAHouseDeclinesOnceTheGraceHasRunOut() throws {
    var fixture = try merchantHouse()
    for _ in 0 ..< grace(fixture) {
        interval(&fixture)
    }
    var house = try pop(fixture)
    #expect(house.population < 8)
    #expect(house.tier == .merchants)
    run(&fixture, ticks: 22)
    house = try pop(fixture)
    #expect(house.tier == .citizens)
    #expect(house.population <= HouseTier.citizens.capacity)
}

/// A merchant house short of `good` for its grace and then 120 ticks, the other needs in stock.
private func declinesWithout(_ good: Good) throws -> HousePopulation {
    var fixture = try merchantHouse()
    run(&fixture, ticks: Int(HousePopulation.consumptionIntervalTicks) * (grace(fixture) - 1) + 121, missing: [good])
    return try pop(fixture)
}

@Test("scenario: merchants without bread decline to citizens")
func scenarioMerchantsWithoutBreadDeclineToCitizens() throws {
    let house = try declinesWithout(.bread)
    #expect(house.tier == .citizens)
    #expect(house.population <= 6)
}

@Test("scenario: merchants without cloth decline to citizens")
func scenarioMerchantsWithoutClothDeclineToCitizens() throws {
    let house = try declinesWithout(.cloth)
    #expect(house.tier == .citizens)
    #expect(house.population <= 6)
}

@Test("scenario: a recovered need resets the count")
func scenarioARecoveredNeedResetsTheCount() throws {
    var fixture = try merchantHouse()
    let waiting = grace(fixture) - 1
    try #require(waiting >= 1)
    for _ in 0 ..< waiting {
        interval(&fixture)
    }
    interval(&fixture, missing: [])
    #expect(try pop(fixture).shortIntervals(of: .tools) == 0)
    for _ in 0 ..< waiting {
        interval(&fixture)
    }
    let house = try pop(fixture)
    #expect(house.population == 8)
    #expect(house.tier == .merchants)
}

@Test("scenario: growth waits during the grace")
func scenarioGrowthWaitsDuringTheGrace() throws {
    var fixture = try merchantHouse(residents: 4)
    try #require(grace(fixture) >= 2)
    interval(&fixture)
    #expect(try pop(fixture).population == 4)
}

@Test("scenario: an empty house falls at once")
func scenarioAnEmptyHouseFallsAtOnce() throws {
    var fixture = try merchantHouse(residents: 0)
    run(&fixture, ticks: 121)
    #expect(try pop(fixture).tier == .citizens)
}

@Test("scenario: counts of needs the tier does not have are dropped")
func scenarioCountsOfNeedsTheTierDoesNotHaveAreDropped() throws {
    var fixture = try merchantHouse()
    var foodBefore = 0
    for _ in 0 ..< 3000 where try pop(fixture).tier == .merchants {
        foodBefore = try pop(fixture).shortIntervals(of: .food)
        run(&fixture, ticks: 1, missing: [.tools, .food])
    }
    let house = try pop(fixture)
    #expect(house.tier == .citizens)
    #expect(house.shortIntervals(of: .tools) == 0)
    #expect(foodBefore >= grace(fixture))
    #expect(house.shortIntervals(of: .food) == foodBefore)
}

@Test func shortIntervalsSaturate() {
    var house = HousePopulation()
    for _ in 0 ..< 300 {
        house.recordConsumption(of: .tools, short: true)
    }
    #expect(house.shortIntervals(of: .tools) == 255)
    #expect(house.isShort(.tools))
    house.recordConsumption(of: .tools, short: false)
    #expect(house.shortIntervals(of: .tools) == 0)
    #expect(!house.isShort(.tools))
}

@Test func clearingShortagesForgetsTheCounts() {
    var house = HousePopulation()
    house.recordConsumption(of: .tools, short: true)
    house.clearShortages()
    #expect(house.shortIntervals(of: .tools) == 0)
    #expect(!house.isShort(.tools))
}
