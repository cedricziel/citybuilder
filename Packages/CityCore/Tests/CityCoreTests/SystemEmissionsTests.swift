import Foundation
import Testing
@testable import CityCore

// Tests for `world-events` spec — "Events emitted by each existing system"
// requirement. Each @Test maps to a #### Scenario in
// openspec/changes/add-audio-foundation/specs/world-events/spec.md.

// MARK: - Command application

@Test("scenario: building placement emits an event")
func scenarioBuildingPlacementEmitsAnEvent() {
    var world = World.fixtureWithTerrain(width: 6, height: 6, fill: .grass, seed: 1)
    let anchor = TileCoordinate(x: 1, y: 1)
    world.enqueue(.place(.road, at: anchor))
    let result = world.tick()
    let placements = result.events.filter {
        if case let .buildingPlaced(_, kind, eventAnchor) = $0 {
            return kind == .road && eventAnchor == anchor
        }
        return false
    }
    #expect(placements.count == 1)
}

@Test("scenario: demolish emits an event")
func scenarioDemolishEmitsAnEvent() {
    var world = World.fixtureWithTerrain(width: 6, height: 6, fill: .grass, seed: 1)
    let anchor = TileCoordinate(x: 1, y: 1)
    world.enqueue(.place(.road, at: anchor))
    world.tick()
    world.enqueue(.demolish(at: anchor))
    let result = world.tick()
    let demolitions = result.events.filter {
        if case let .buildingDemolished(_, kind, eventAnchor) = $0 {
            return kind == .road && eventAnchor == anchor
        }
        return false
    }
    #expect(demolitions.count == 1)
}

@Test("scenario: forest harvest emits an event")
func scenarioForestHarvestEmitsAnEvent() {
    var world = World.fixtureWithTerrain(width: 6, height: 6, fill: .forest, seed: 1)
    let target = TileCoordinate(x: 2, y: 3)
    world.enqueue(.harvestForest(at: target))
    let result = world.tick()
    let harvests = result.events.compactMap { event -> TileCoordinate? in
        if case let .forestHarvested(at) = event { return at }
        return nil
    }
    #expect(harvests == [target])
}

// MARK: - Construction

@Test("scenario: construction completion emits exactly one event")
func scenarioConstructionCompletionEmitsExactlyOneEvent() {
    // Use a road (buildDurationTicks = 1) so completion fires deterministically
    // on the first post-place tick.
    var world = World.fixtureWithTerrain(width: 6, height: 6, fill: .grass, seed: 1)
    let anchor = TileCoordinate(x: 1, y: 1)
    world.enqueue(.place(.road, at: anchor))
    let result = world.tick()
    let completions = result.events.filter {
        if case let .constructionCompleted(_, kind, eventAnchor) = $0 {
            return kind == .road && eventAnchor == anchor
        }
        return false
    }
    #expect(completions.count == 1)
    // Subsequent ticks must not emit a duplicate.
    let nextResult = world.tick()
    #expect(!nextResult.events.contains(where: {
        if case .constructionCompleted = $0 { return true }
        return false
    }))
}

// MARK: - Production

@Test("scenario: production cycle emits once per cycle")
func scenarioProductionCycleEmitsOncePerCycle() {
    var world = World.fixtureWithTerrain(width: 6, height: 6, fill: .grass, seed: 1)
    let anchor = TileCoordinate(x: 1, y: 1)
    world.enqueue(.place(.sawmill, at: anchor))
    world.tick()
    let id = world.snapshot().occupiedTiles[anchor]
    guard let buildingId = id else {
        Issue.record("sawmill placement did not produce an entity id")
        return
    }
    // Advance through construction (buildDurationTicks = 30).
    for _ in 0 ..< 30 {
        world.tick()
    }
    // Seed wood so the cycle can run.
    world.stockpiles[buildingId]?.deposit(.wood, amount: 5)
    // One cycle is 25 ticks. Count cycles over 30 ticks; expect at least one.
    var cycleEvents: [WorldEvent] = []
    for _ in 0 ..< 30 {
        cycleEvents.append(contentsOf: world.tick().events.filter {
            if case let .productionCycleCompleted(producer, _) = $0 {
                return producer == buildingId
            }
            return false
        })
    }
    #expect(cycleEvents.count >= 1, "sawmill should complete at least one cycle in 30 ticks")
}

@Test("scenario: stall emits an event the tick the stall begins")
func scenarioStallEmitsAnEventTheTickTheStallBegins() {
    // A sawmill with no inputs stalls the tick its production system first
    // runs against it as operational — which is the same tick the building
    // flips from constructing to operational (advanceBuildings runs before
    // runProductionSystem in the tick body).
    var world = World.fixtureWithTerrain(width: 6, height: 6, fill: .grass, seed: 1)
    let anchor = TileCoordinate(x: 1, y: 1)
    world.enqueue(.place(.sawmill, at: anchor))
    world.tick()
    let id = world.snapshot().occupiedTiles[anchor]
    guard let buildingId = id else {
        Issue.record("sawmill placement failed")
        return
    }
    // Run well past construction completion. Exactly one stall must have
    // fired across this window: the tick the building first ran as
    // operational, with no wood inputs.
    var allEvents: [WorldEvent] = []
    for _ in 0 ..< 40 {
        allEvents.append(contentsOf: world.tick().events)
    }
    let stalls = allEvents.filter {
        if case let .productionStalled(producer) = $0 { return producer == buildingId }
        return false
    }
    #expect(stalls.count == 1, "exactly one productionStalled across the construction + idle window")
}

@Test("scenario: stall resolution emits a resumed event once")
func scenarioStallResolutionEmitsAResumedEventOnce() {
    var world = World.fixtureWithTerrain(width: 6, height: 6, fill: .grass, seed: 1)
    let anchor = TileCoordinate(x: 1, y: 1)
    world.enqueue(.place(.sawmill, at: anchor))
    world.tick()
    let id = world.snapshot().occupiedTiles[anchor]
    guard let buildingId = id else {
        Issue.record("sawmill placement failed")
        return
    }
    for _ in 0 ..< 30 {
        world.tick()
    }
    // Stall.
    _ = world.tick()
    // Provide inputs — next tick resumes.
    world.stockpiles[buildingId]?.deposit(.wood, amount: 5)
    let resumeTick = world.tick()
    let resumes = resumeTick.events.filter {
        if case let .productionResumed(producer) = $0 { return producer == buildingId }
        return false
    }
    #expect(resumes.count == 1)
}

// MARK: - Carriers

@Test("scenario: carrier arrival emits once at the destination tick")
func scenarioCarrierArrivalEmitsOnceAtTheDestinationTick() {
    // Inject a carrier directly so we don't need to set up a full
    // producer-warehouse-road graph just to verify the arrival event.
    var world = World.fixtureWithTerrain(width: 4, height: 4, fill: .grass, seed: 1)
    let carrierId = EntityID(raw: 99)
    let warehouseId = EntityID(raw: 100)
    // The warehouse needs a stockpile entry for the deposit to land somewhere.
    world.stockpiles[warehouseId] = Stockpile(capacity: 16)
    let path = [
        TileCoordinate(x: 0, y: 0),
        TileCoordinate(x: 1, y: 0)
    ]
    let carrier = Carrier(
        id: carrierId,
        path: path,
        pathIndex: 1, // already at the last tile — `hasArrived == true`
        mission: .deliver(good: .wood, amount: 1, fromProducer: EntityID(raw: 50), toWarehouse: warehouseId)
    )
    world.carriers[carrierId] = carrier
    let result = world.tick()
    let arrivals = result.events.filter {
        if case let .carrierArrived(eventCarrierId, _, good, amount) = $0 {
            return eventCarrierId == carrierId && good == .wood && amount == 1
        }
        return false
    }
    #expect(arrivals.count == 1)
}

// MARK: - Economy

@Test("scenario: tax interval emits a single event")
func scenarioTaxIntervalEmitsASingleEvent() {
    // Seed a house with population so taxes > 0 on the interval boundary.
    // (Empty cities are tested separately by the "tax interval is silent
    // when no income" scenario.)
    var world = World.fixtureWithTerrain(width: 4, height: 4, fill: .grass, seed: 1)
    let houseId = EntityID(raw: 1)
    world.buildings[houseId] = Building(
        id: houseId,
        kind: .house,
        anchor: TileCoordinate(x: 1, y: 1),
        state: .operational
    )
    var pop = HousePopulation()
    pop.population = 3
    world.populations[houseId] = pop

    var preTaxEvents: [WorldEvent] = []
    for _ in 0 ..< 49 {
        preTaxEvents.append(contentsOf: world.tick().events)
    }
    #expect(!preTaxEvents.contains(where: {
        if case .taxesCollected = $0 { return true }
        return false
    }))
    let taxTick = world.tick()
    let taxes = taxTick.events.filter {
        if case .taxesCollected = $0 { return true }
        return false
    }
    #expect(taxes.count == 1)
}

@Test("scenario: tax interval is silent when no income")
func scenarioTaxIntervalIsSilentWhenNoIncome() {
    // An empty city (zero population) crosses the 50-tick tax boundary
    // without firing the event — the audio coin cue stays silent rather
    // than playing a 5-second heartbeat for amount=0.
    var world = World.fixtureWithTerrain(width: 4, height: 4, fill: .grass, seed: 1)
    var allEvents: [WorldEvent] = []
    for _ in 0 ..< 60 {
        allEvents.append(contentsOf: world.tick().events)
    }
    #expect(!allEvents.contains(where: {
        if case .taxesCollected = $0 { return true }
        return false
    }))
}

@Test("scenario: upkeep interval is silent when no upkeep")
func scenarioUpkeepIntervalIsSilentWhenNoUpkeep() {
    // A city with no operational buildings (or only zero-upkeep ones) does
    // not emit `upkeepPaid` per interval.
    var world = World.fixtureWithTerrain(width: 4, height: 4, fill: .grass, seed: 1)
    var allEvents: [WorldEvent] = []
    for _ in 0 ..< 60 {
        allEvents.append(contentsOf: world.tick().events)
    }
    #expect(!allEvents.contains(where: {
        if case .upkeepPaid = $0 { return true }
        return false
    }))
}

@Test("scenario: bankruptcy warning emits once at deficit start")
func scenarioBankruptcyWarningEmitsOnceAtDeficitStart() {
    var world = World.fixtureWithTerrain(width: 4, height: 4, fill: .grass, seed: 1)
    world.economy.balance = -1
    // First tick — balance just went negative (was 0 on prior tick — fixture
    // construction; bankruptcyDeficitTicks was 0). Emit warning exactly once.
    let firstTick = world.tick()
    let warnings = firstTick.events.filter {
        if case .bankruptcyWarning = $0 { return true }
        return false
    }
    #expect(warnings.count == 1)
    // Next tick: still negative, no duplicate warning.
    let secondTick = world.tick()
    #expect(!secondTick.events.contains(where: {
        if case .bankruptcyWarning = $0 { return true }
        return false
    }))
}

@Test("scenario: game over emits exactly once")
func scenarioGameOverEmitsExactlyOnce() {
    var world = World.fixtureWithTerrain(width: 4, height: 4, fill: .grass, seed: 1)
    world.economy.balance = -1
    // Need bankruptcyGraceTicks (50) consecutive deficit ticks for gameOver.
    var gameOverCount = 0
    for _ in 0 ..< Int(Economy.bankruptcyGraceTicks) {
        gameOverCount += world.tick().events.count(where: {
            if case .gameOver = $0 { return true }
            return false
        })
    }
    #expect(gameOverCount == 1, "exactly one gameOver in the grace window")
    // Past the gameOver tick, no further events should fire (economy short-
    // circuits on isBankrupt).
    let postTick = world.tick()
    #expect(!postTick.events.contains(where: {
        if case .gameOver = $0 { return true }
        return false
    }))
}
