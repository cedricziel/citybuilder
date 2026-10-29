import Foundation
import Testing
@testable import CityCore

// Scenarios from openspec/changes/add-campaigns (difficulty-and-goals /
// More goal kinds, Holding goals, Bonus goals).

/// A grass world in spring 1200 with an active calendar and `goals`.
func goalWorld(_ goals: [GoalState]) -> World {
    var world = eventsWorld(size: 24)
    world.seasonalEvents.enabled = false
    world.goals = goals
    world.economy.balance = 100_000
    return world
}

@discardableResult
func runGoals(_ world: inout World, untilTick tick: UInt64) -> [WorldEvent] {
    runEvents(&world, untilTick: tick)
}

/// A house without a building, so it counts as the player's.
func setResidents(_ count: UInt32, tier: HouseTier = .peasants, in world: inout World) {
    var house = HousePopulation()
    house.population = count
    house.tier = tier
    world.populations[EntityID(raw: 9999)] = house
}

@Test("scenario: building goal counts only operational buildings")
func scenarioBuildingGoalCountsOnlyOperationalBuildings() {
    var world = goalWorld([GoalState(goal: .buildings(.windmill, 2))])
    addOperational(.windmill, at: TileCoordinate(x: 2, y: 2), in: &world)
    let second = addOperational(.windmill, at: TileCoordinate(x: 8, y: 2), in: &world)
    world.buildings[second]?.state = .constructing
    runGoals(&world, untilTick: 10)
    let early = world.goals[0].isMet
    #expect(!early)
    world.buildings[second]?.state = .operational
    runGoals(&world, untilTick: 20)
    let late = world.goals[0].isMet
    #expect(late)
}

@Test("scenario: research goal")
func scenarioResearchGoal() {
    var world = goalWorld([GoalState(goal: .research(.metallurgy))])
    world.research = ResearchState(researched: [.scholarship])
    runGoals(&world, untilTick: 10)
    let before = world.goals[0].isMet
    #expect(!before)
    world.research = ResearchState(researched: [.scholarship, .metallurgy])
    runGoals(&world, untilTick: 20)
    let after = world.goals[0].isMet
    #expect(after)
}

@Test("scenario: trade earnings ignore tax and caravans")
func scenarioTradeEarningsIgnoreTaxAndCaravans() {
    var world = goalWorld([GoalState(goal: .tradeEarnings(300))])
    world.recordGoalCounters([
        .marketTraded(good: .planks, quantity: 20, total: 120, direction: .sold),
        .caravanSold(building: EntityID(raw: 1), goods: [.wine: 5], revenue: 150),
        .taxesCollected(amount: 40),
        .marketTraded(good: .food, quantity: 5, total: 30, direction: .bought)
    ])
    let progress = world.progress(toward: .tradeEarnings(300))
    #expect(progress.current == 120)
    #expect(progress.target == 300)
}

@Test("selling at a rival port counts as trade earnings, buying does not")
func sellingAtARivalPortCountsAsTradeEarnings() {
    var world = goalWorld([])
    world.recordGoalCounters([
        .tradeCompleted(rival: 1, good: .tools, quantity: 4, total: 80, direction: .sold),
        .tradeCompleted(rival: 1, good: .wood, quantity: 4, total: 20, direction: .bought)
    ])
    let earnings = world.goalCounters.tradeEarnings
    #expect(earnings == 80)
}

@Test("a market sale counts toward trade earnings")
func aMarketSaleCountsTowardTradeEarnings() {
    var world = goalWorld([])
    let center = world.testPlace(.townCenter, at: TileCoordinate(x: 2, y: 2), owner: .player)
    var stock = world.stockpiles[center] ?? Stockpile(capacity: 100)
    _ = stock.deposit(.planks, amount: 20)
    world.stockpiles[center] = stock
    world.enqueue(.marketSell(center, .planks, 20))
    let events = world.tick().events
    let total = events.reduce(Int64(0)) { sum, event in
        if case let .marketTraded(_, _, total, .sold) = event { sum + total } else { sum }
    }
    let earnings = world.goalCounters.tradeEarnings
    #expect(total > 0)
    #expect(earnings == total)
}

@Test("monuments and finished commissions count as signature projects")
func monumentsAndFinishedCommissionsCountAsSignatureProjects() {
    var world = goalWorld([])
    let monument = addOperational(.monument, at: TileCoordinate(x: 2, y: 2), in: &world)
    let gallery = addOperational(.gallery, at: TileCoordinate(x: 10, y: 2), in: &world)
    let rivalGallery = addOperational(.gallery, at: TileCoordinate(x: 2, y: 12), in: &world)
    world.buildings[rivalGallery]?.owner = .rival(1)
    world.recordGoalCounters([
        .monumentCompleted(building: monument),
        .commissionEnded(building: gallery),
        .commissionEnded(building: rivalGallery),
        .commissionStarted(building: gallery)
    ])
    let progress = world.progress(toward: .signatureProjects(3))
    #expect(progress.current == 2)
}

@Test("scenario: net income uses the last season")
func scenarioNetIncomeUsesTheLastSeason() {
    var world = goalWorld([GoalState(goal: .netIncome(100))])
    let none = world.progress(toward: .netIncome(100)).current
    #expect(none == 0)
    var season = SeasonStatistics()
    season.money.tax = 480
    season.money.upkeep = 336
    world.statistics.close(season)
    let progress = world.progress(toward: .netIncome(100))
    #expect(progress.current == 144)
    #expect(progress.target == 100)
    runGoals(&world, untilTick: 10)
    let met = world.goals[0].isMet
    #expect(met)
}

@Test("treasury goal reads the balance")
func treasuryGoalReadsTheBalance() {
    var world = goalWorld([GoalState(goal: .treasury(1200))])
    world.economy.balance = 1100
    runGoals(&world, untilTick: 10)
    let early = world.goals[0].isMet
    #expect(!early)
    world.economy.balance = 1250
    runGoals(&world, untilTick: 20)
    let late = world.goals[0].isMet
    #expect(late)
}

@Test("scenario: goal counters survive a save")
func scenarioGoalCountersSurviveASave() throws {
    var world = goalWorld([GoalState(goal: .tradeEarnings(300), isBonus: true, holdsForSeason: true)])
    world.recordGoalCounters([.marketTraded(good: .planks, quantity: 20, total: 120, direction: .sold)])
    world.goalCounters.landedAtHome[.ore] = 12
    world.loseConditions = [LoseConditionState(condition: .collapse(below: 40))]
    let data = try JSONEncoder().encode(world)
    let loaded = try JSONDecoder().decode(World.self, from: data)
    let earnings = loaded.goalCounters.tradeEarnings
    #expect(earnings == 120)
    #expect(loaded == world)
}

// MARK: - Holding goals

@Test("scenario: holding resets on a dip")
func scenarioHoldingResetsOnADip() {
    let goal = Goal.population(20, atLeast: .merchants)
    var world = goalWorld([GoalState(goal: goal, holdsForSeason: true)])
    setResidents(20, tier: .merchants, in: &world)
    runGoals(&world, untilTick: 300)
    setResidents(19, tier: .merchants, in: &world)
    runGoals(&world, untilTick: 310)
    setResidents(20, tier: .merchants, in: &world)
    runGoals(&world, untilTick: 900)
    let beforeSeason = world.goals[0].isMet
    #expect(!beforeSeason)
    runGoals(&world, untilTick: 920)
    let afterSeason = world.goals[0].isMet
    #expect(afterSeason)
}

@Test("scenario: holding goal is met after a season")
func scenarioHoldingGoalIsMetAfterASeason() {
    let goal = Goal.population(20, atLeast: .merchants)
    var world = goalWorld([GoalState(goal: goal, holdsForSeason: true), GoalState(goal: .age(.industrial))])
    setResidents(25, tier: .merchants, in: &world)
    runGoals(&world, untilTick: 600)
    let early = world.goals[0].isMet
    #expect(!early)
    runGoals(&world, untilTick: 610)
    let met = world.goals[0].isMet
    #expect(met)
    setResidents(3, tier: .merchants, in: &world)
    runGoals(&world, untilTick: 700)
    let stays = world.goals[0].isMet
    #expect(stays)
}

// MARK: - Bonus goals

@Test("scenario: win without the bonus")
func scenarioWinWithoutTheBonus() {
    var world = goalWorld([
        GoalState(goal: .treasury(10)),
        GoalState(goal: .population(1, atLeast: .peasants)),
        GoalState(goal: .age(.industrial), isBonus: true)
    ])
    setResidents(4, in: &world)
    let events = runGoals(&world, untilTick: 10)
    let wins = events.count { $0 == .scenarioWon }
    #expect(world.scenarioWon)
    #expect(wins == 1)
    #expect(world.laurels == 0)
}

@Test("scenario: laurels count met bonus goals")
func scenarioLaurelsCountMetBonusGoals() {
    var world = goalWorld([
        GoalState(goal: .age(.industrial)),
        GoalState(goal: .treasury(10), isBonus: true),
        GoalState(goal: .research(.metallurgy), isBonus: true)
    ])
    world.research = ResearchState(researched: [.scholarship])
    runGoals(&world, untilTick: 10)
    let notYet = world.scenarioWon
    #expect(!notYet)
    world.age = .industrial
    runGoals(&world, untilTick: 20)
    #expect(world.scenarioWon)
    #expect(world.laurels == 1)
    world.research = ResearchState(researched: [.scholarship, .metallurgy])
    runGoals(&world, untilTick: 40)
    #expect(world.laurels == 1)
}

extension World {
    /// Runs the scenario's event pass over `events` outside a tick.
    mutating func recordGoalCounters(_ events: [WorldEvent]) {
        var events = events
        runScenarioRecords(events: &events)
    }
}
