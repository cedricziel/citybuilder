import Foundation
import Testing
@testable import CityCore

// Scenarios from openspec/changes/add-campaigns (difficulty-and-goals /
// Goals, Lose conditions, and the landed-by-ship counter).

private let ticksPerYear = CalendarState.ticksPerYear

private func lost(_ events: [WorldEvent]) -> [LossReason] {
    events.compactMap { if case let .scenarioLost(reason) = $0 { reason } else { nil } }
}

@Test("scenario: a lost game is never won")
func scenarioALostGameIsNeverWon() {
    var world = goalWorld([GoalState(goal: .age(.industrial))])
    world.loseConditions = [LoseConditionState(condition: .deadline(year: 1201))]
    let events = runGoals(&world, untilTick: ticksPerYear)
    let reasons = lost(events)
    #expect(reasons == [.deadline])
    world.age = .industrial
    let later = runGoals(&world, untilTick: ticksPerYear + 30)
    let wins = later.count { $0 == .scenarioWon }
    #expect(!world.scenarioWon)
    #expect(wins == 0)
}

@Test("scenario: deadline passes")
func scenarioDeadlinePasses() {
    var world = goalWorld([GoalState(goal: .population(40, atLeast: .peasants))])
    world.loseConditions = [LoseConditionState(condition: .deadline(year: 1206))]
    let before = runGoals(&world, untilTick: 6 * ticksPerYear - 1)
    let early = lost(before)
    #expect(early.isEmpty)
    let tick = world.tick().events
    let reasons = lost(tick)
    #expect(reasons == [.deadline])
    let event = WorldEvent.scenarioLost(.deadline)
    let other = WorldEvent.scenarioLost(.collapse)
    #expect(tick.contains(event))
    #expect(event != other)
    #expect(world.scenarioLoss == .deadline)
    setResidents(50, in: &world)
    let after = runGoals(&world, untilTick: 6 * ticksPerYear + 30)
    let again = lost(after)
    let met = world.goals[0].isMet
    #expect(again.isEmpty)
    #expect(!met)
}

@Test("scenario: deadline met in time")
func scenarioDeadlineMetInTime() {
    var world = goalWorld([GoalState(goal: .population(40, atLeast: .peasants))])
    world.loseConditions = [LoseConditionState(condition: .deadline(year: 1206))]
    runGoals(&world, untilTick: 5 * ticksPerYear + 100)
    setResidents(40, in: &world)
    let events = runGoals(&world, untilTick: 6 * ticksPerYear + 20)
    let reasons = lost(events)
    #expect(world.scenarioWon)
    #expect(reasons.isEmpty)
    #expect(world.scenarioLoss == nil)
}

@Test("scenario: a rival wins the race")
func scenarioARivalWinsTheRace() {
    var world = goalWorld([GoalState(goal: .age(.renaissance))])
    world.loseConditions = [LoseConditionState(condition: .rivalRace(.age(.renaissance)))]
    world.testSeatRival(1, age: .medieval)
    world.testSeatRival(2, age: .renaissance)
    let events = runGoals(&world, untilTick: 10)
    let reasons = lost(events)
    #expect(reasons == [.rivalRace(2)])
}

@Test("scenario: the player wins a tied race")
func scenarioThePlayerWinsATiedRace() {
    var world = goalWorld([GoalState(goal: .age(.renaissance)), GoalState(goal: .age(.industrial))])
    world.loseConditions = [LoseConditionState(condition: .rivalRace(.age(.renaissance)))]
    world.testSeatRival(1, age: .renaissance)
    world.age = .renaissance
    let events = runGoals(&world, untilTick: 30)
    let reasons = lost(events)
    let raceMet = world.goals[0].isMet
    let cleared = world.loseConditions[0].settled
    #expect(reasons.isEmpty)
    #expect(raceMet)
    #expect(cleared)
}

@Test("a population race counts the rival's residents")
func aPopulationRaceCountsTheRivalsResidents() {
    var world = goalWorld([GoalState(goal: .population(60, atLeast: .peasants))])
    world.loseConditions = [LoseConditionState(condition: .rivalRace(.population(60, atLeast: .peasants)))]
    world.testSeatRival(1, age: .medieval)
    let house = world.testAddHouse(owner: .rival(1), residents: 59)
    let quiet = lost(runGoals(&world, untilTick: 10))
    #expect(quiet.isEmpty)
    world.populations[house]?.population = 60
    let reasons = lost(runGoals(&world, untilTick: 20))
    #expect(reasons == [.rivalRace(1)])
}

@Test("scenario: collapse after a dip that lasts")
func scenarioCollapseAfterADipThatLasts() {
    var world = goalWorld([GoalState(goal: .age(.industrial))])
    world.loseConditions = [LoseConditionState(condition: .collapse(below: 40))]
    setResidents(35, in: &world)
    let unarmed = lost(runGoals(&world, untilTick: 700))
    #expect(unarmed.isEmpty)
    setResidents(52, in: &world)
    runGoals(&world, untilTick: 710)
    setResidents(35, in: &world)
    let short = lost(runGoals(&world, untilTick: 1300))
    #expect(short.isEmpty)
    let reasons = lost(runGoals(&world, untilTick: 1320))
    #expect(reasons == [.collapse])
}

@Test("scenario: a short dip is not a collapse")
func scenarioAShortDipIsNotACollapse() {
    var world = goalWorld([GoalState(goal: .age(.industrial))])
    world.loseConditions = [LoseConditionState(condition: .collapse(below: 40))]
    setResidents(52, in: &world)
    runGoals(&world, untilTick: 10)
    setResidents(35, in: &world)
    runGoals(&world, untilTick: 300)
    setResidents(40, in: &world)
    let events = runGoals(&world, untilTick: 1500)
    let reasons = lost(events)
    #expect(reasons.isEmpty)
    #expect(world.scenarioLoss == nil)
}

@Test("scenario: bankruptcy loses the scenario")
func scenarioBankruptcyLosesTheScenario() {
    var world = goalWorld([GoalState(goal: .age(.industrial))])
    world.economy.balance = -1000
    let events = runGoals(&world, untilTick: 200)
    let reasons = lost(events)
    let gameOver = events.contains(.gameOver)
    #expect(gameOver)
    #expect(reasons == [.bankruptcy])
    world.enqueue(.place(.house, at: TileCoordinate(x: 6, y: 6)))
    world.tick()
    #expect(world.occupiedTiles[TileCoordinate(x: 6, y: 6)] == nil)
}

@Test("a sandbox bankruptcy loses no scenario")
func aSandboxBankruptcyLosesNoScenario() {
    var world = goalWorld([])
    world.economy.balance = -1000
    let events = runGoals(&world, untilTick: 200)
    let reasons = lost(events)
    #expect(world.economy.gameOver)
    #expect(reasons.isEmpty)
}

@Test("scenario: building goes on after a loss")
func scenarioBuildingGoesOnAfterALoss() {
    var world = goalWorld([GoalState(goal: .age(.industrial))])
    world.loseConditions = [LoseConditionState(condition: .deadline(year: 1201))]
    runGoals(&world, untilTick: ticksPerYear + 10)
    #expect(world.scenarioLoss == .deadline)
    world.enqueue(.place(.house, at: TileCoordinate(x: 6, y: 6)))
    world.tick()
    #expect(world.occupiedTiles[TileCoordinate(x: 6, y: 6)] != nil)
}

// MARK: - Landed by ship

/// Two islands: home under the map's centre (x 0…17) and another (x 22…27),
/// each with a port on its east shore.
private struct TwoShores {
    var world: World
    let homePort: EntityID
    let farPort: EntityID

    init() {
        var world = World.fixtureWithTerrain(width: 30, height: 12, fill: .water, seed: 11)
        for y in 0 ..< world.mapHeight {
            for x in Array(0 ... 17) + Array(22 ... 27) {
                world.terrainGrid[y * world.mapWidth + x] = .grass
            }
        }
        world.economy.credit(100_000)
        world.islands = IslandDetector.detectIslands(
            width: world.mapWidth, height: world.mapHeight, terrain: world.terrainGrid,
            mapHeightForClimate: world.mapHeight, seed: 11
        )
        world.seedUnlimitedTestInventory()
        world.pendingCommands.append(.place(.port, at: TileCoordinate(x: 17, y: 1)))
        world.pendingCommands.append(.place(.port, at: TileCoordinate(x: 27, y: 1)))
        world.tick()
        homePort = world.occupiedTiles[TileCoordinate(x: 17, y: 1)] ?? EntityID(raw: 0)
        farPort = world.occupiedTiles[TileCoordinate(x: 27, y: 1)] ?? EntityID(raw: 0)
        self.world = world
    }

    /// Docks a ship carrying `cargo` at `port` with one unload action.
    mutating func unload(_ good: Good, _ amount: Int, at port: EntityID, shipRaw: UInt32) throws {
        let anchor = try #require(world.buildings[port]?.shipAnchor)
        let routeID = EntityID(raw: shipRaw + 100)
        world.routes[routeID] = Route(
            id: routeID, waypoints: [.port(id: port), .port(id: port == homePort ? farPort : homePort)],
            manifest: [port: [.unloadUpTo(good: good, qty: amount)]], speed: .one, state: .active
        )
        let shipID = EntityID(raw: shipRaw)
        world.ships[shipID] = Ship(
            id: shipID, position: Fixed2D(x: Fixed(Int32(anchor.x)), y: Fixed(Int32(anchor.y))),
            heading: .zero, routeID: routeID, waypointIdx: 0, cargo: [good: amount],
            state: .docked, shipClass: .default
        )
        world.tick()
    }
}

@Test("scenario: ship landings count at a home port")
func scenarioShipLandingsCountAtAHomePort() throws {
    var shores = TwoShores()
    try shores.unload(.ore, 12, at: shores.homePort, shipRaw: 500)
    try shores.unload(.ore, 5, at: shores.farPort, shipRaw: 501)
    let progress = shores.world.progress(toward: .landedByShip(.ore, 30))
    #expect(progress.current == 12)
    #expect(progress.target == 30)
}
