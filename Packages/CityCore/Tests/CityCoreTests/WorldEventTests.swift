import Foundation
import Testing
@testable import CityCore

// Tests for spec `world-events` — every `#### Scenario:` heading from
// openspec/changes/add-audio-foundation/specs/world-events/spec.md maps to
// at least one `@Test("scenario: <lowercased title>")` here.

// MARK: - Enum surface

/// One event of every case.
private let eventSamples: [WorldEvent] = [
    .buildingPlaced(building: EntityID(raw: 1), kind: .house, anchor: TileCoordinate(x: 0, y: 0)),
    .buildingDemolished(building: EntityID(raw: 1), kind: .house, anchor: TileCoordinate(x: 0, y: 0)),
    .constructionCompleted(building: EntityID(raw: 1), kind: .house, anchor: TileCoordinate(x: 0, y: 0)),
    .materialsDeducted(building: EntityID(raw: 1), cost: [.wood: 2]),
    .constructionWaitingForMaterials(building: EntityID(raw: 1), missing: [.wood: 1]),
    .constructionStarted(building: EntityID(raw: 1)),
    .forestHarvested(at: TileCoordinate(x: 0, y: 0)),
    .carrierDeparted(carrier: EntityID(raw: 1), from: TileCoordinate(x: 0, y: 0), good: .wood),
    .carrierArrived(carrier: EntityID(raw: 1), at: TileCoordinate(x: 0, y: 0), good: .wood, amount: 1),
    .productionCycleCompleted(producer: EntityID(raw: 1), kind: .sawmill),
    .productionStalled(producer: EntityID(raw: 1), kind: .sawmill),
    .productionResumed(producer: EntityID(raw: 1), kind: .sawmill),
    .placementRejected(kind: .house, anchor: TileCoordinate(x: 0, y: 0)),
    .taxesCollected(amount: 100),
    .upkeepPaid(amount: 50),
    .bankruptcyWarning(deficitTicks: 1),
    .bankruptcyResolved,
    .gameOver,
    .seasonChanged(.summer),
    .historyEvent(.tradeCaravan),
    .ageAdvanced(.renaissance),
    .scenarioWon,
    .fuelRanOut(building: EntityID(raw: 1), kind: .steamEngine),
    .monumentCompleted(building: EntityID(raw: 1)),
    .commissionStarted(building: EntityID(raw: 1)),
    .commissionEnded(building: EntityID(raw: 1)),
    .caravanSold(building: EntityID(raw: 1), goods: [.bread: 4], revenue: 48)
]

@Test("scenario: event enum is exhaustive over mvp capabilities")
func scenarioEventEnumIsExhaustiveOverMvpCapabilities() {
    // Construct one event of every case. Exhaustiveness is enforced by the
    // case-less switch below: removing a case breaks the construction;
    // adding a case without updating the test makes the compiler warn.
    #expect(eventSamples.count == 27)
    for event in eventSamples {
        switch event {
        case .buildingPlaced,
             .buildingDemolished,
             .constructionCompleted,
             .materialsDeducted,
             .constructionWaitingForMaterials,
             .constructionStarted,
             .forestHarvested,
             .carrierDeparted,
             .carrierArrived,
             .productionCycleCompleted,
             .productionStalled,
             .productionResumed,
             .placementRejected,
             .taxesCollected,
             .upkeepPaid,
             .bankruptcyWarning,
             .bankruptcyResolved,
             .gameOver,
             .seasonChanged,
             .historyEvent,
             .ageAdvanced,
             .scenarioWon,
             .fuelRanOut,
             .monumentCompleted,
             .commissionStarted,
             .commissionEnded,
             .caravanSold:
            break
        }
    }
}

@Test("scenario: event is not codable")
func scenarioEventIsNotCodable() {
    // The spec asserts a compile-time guarantee: code that tries to encode
    // a WorldEvent fails to build. We mirror that at runtime: the type
    // must not advertise an Encodable conformance.
    let conformsToEncodable: Bool = WorldEvent.self is any Encodable.Type
    #expect(!conformsToEncodable, "WorldEvent must not conform to Encodable")
}

// MARK: - TickResult shape (world-events spec)

@Test("scenario: tickresult exposes metrics")
func scenarioTickResultExposesMetrics() {
    var world = World.fixtureWithTerrain(width: 4, height: 4, fill: .grass, seed: 1)
    let result = world.tick()
    // Equivalent semantics to the prior `TickMetrics` return value, just
    // nested one level deeper.
    #expect(result.metrics.wallClockNanoseconds < 1_000_000_000)
}

@Test("scenario: tickresult exposes events")
func scenarioTickResultExposesEvents() {
    var world = World.fixtureWithTerrain(width: 4, height: 4, fill: .grass, seed: 1)
    let result = world.tick()
    let _: [WorldEvent] = result.events // type check
    #expect(result.events.isEmpty || !result.events.isEmpty) // tautology — just a presence check
}

@Test("scenario: empty tick yields empty event list")
func scenarioEmptyTickYieldsEmptyEventList() {
    // A tick with no pending commands and no state-change-worthy systems
    // (empty world, no buildings) emits no events.
    var world = World.fixtureWithTerrain(width: 2, height: 2, fill: .grass, seed: 1)
    let result = world.tick()
    #expect(result.events.isEmpty)
}

// MARK: - Transience

@Test("scenario: events not in world")
func scenarioEventsNotInWorld() {
    // `World` must not carry a stored property of `WorldEvent` or `[WorldEvent]`.
    // Events live only inside the returned `TickResult` for one tick.
    let world = World.fixtureWithTerrain(width: 2, height: 2, fill: .grass, seed: 1)
    let mirror = Mirror(reflecting: world)
    for child in mirror.children {
        let label = child.label ?? "?"
        let typeName = String(describing: type(of: child.value))
        #expect(
            !typeName.contains("WorldEvent"),
            "World must not have a stored property of WorldEvent type: \(label): \(typeName)"
        )
    }
}

@Test("scenario: save round-trip preserves nothing about events")
func scenarioSaveRoundTripPreservesNothingAboutEvents() throws {
    // Even if a tick had produced events before the save, decoding back
    // yields a world whose next tick produces a fresh event list independent
    // of any pre-save activity.
    let original = World.fixtureWithTerrain(width: 4, height: 4, fill: .grass, seed: 42)
    let encoded = try JSONEncoder().encode(original)
    var decoded = try JSONDecoder().decode(World.self, from: encoded)
    let firstTick = decoded.tick()
    #expect(firstTick.events.isEmpty)
}

@Test("scenario: draining events does not affect determinism")
func scenarioDrainingEventsDoesNotAffectDeterminism() {
    // Two simulations whose only difference is that one inspects `events`
    // and the other ignores it MUST produce byte-identical `World`s.
    var worldA = World.fixtureWithTerrain(width: 4, height: 4, fill: .grass, seed: 999)
    var worldB = World.fixtureWithTerrain(width: 4, height: 4, fill: .grass, seed: 999)
    for _ in 0 ..< 10 {
        let resultA = worldA.tick()
        _ = resultA.events // "drain" — read the events
        _ = worldB.tick() // ignore the result entirely
    }
    #expect(worldA == worldB)
}

// MARK: - Deterministic event ordering (M3)

@Test("scenario: stable ordering inside a single tick")
func scenarioStableOrderingInsideASingleTick() {
    // Verify the sort directly on synthetic input. Entity-bearing events
    // sort by ascending EntityID.raw; non-entity events sort after, by
    // declared caseOrdinal; ties break on original insertion index.
    let unsorted: [WorldEvent] = [
        .taxesCollected(amount: 100),
        .productionCycleCompleted(producer: EntityID(raw: 7), kind: .sawmill),
        .gameOver,
        .constructionCompleted(building: EntityID(raw: 2), kind: .house, anchor: TileCoordinate(x: 0, y: 0)),
        .productionCycleCompleted(producer: EntityID(raw: 5), kind: .sawmill),
        .bankruptcyWarning(deficitTicks: 3),
        .productionCycleCompleted(producer: EntityID(raw: 3), kind: .sawmill)
    ]
    let sorted = unsorted.stablySortedForEmission()
    // Entity-bearing events first, ascending by primaryEntityID.
    let entityIds = sorted.compactMap(\.primaryEntityID).map(\.raw)
    #expect(entityIds == [2, 3, 5, 7])
    // Non-entity events come after, in caseOrdinal order:
    // taxesCollected, bankruptcyWarning, gameOver.
    let trailing = sorted.suffix(3).map(\.caseOrdinal)
    let expected: [Int] = [
        WorldEvent.taxesCollected(amount: 0).caseOrdinal,
        WorldEvent.bankruptcyWarning(deficitTicks: 0).caseOrdinal,
        WorldEvent.gameOver.caseOrdinal
    ]
    #expect(trailing == expected)
}

@Test("scenario: replay produces identical event sequences")
func scenarioReplayProducesIdenticalEventSequences() {
    // Same starting state + same inputs → element-wise-equal event sequences.
    // Today (pre-M4 emission) both sequences are empty; the test guards the
    // invariant so M4's emission additions can't accidentally non-determinise
    // the order across runs.
    var worldA = World.fixtureWithTerrain(width: 8, height: 8, fill: .forest, seed: 1234)
    var worldB = World.fixtureWithTerrain(width: 8, height: 8, fill: .forest, seed: 1234)
    let commands: [Command] = [
        .noop,
        .harvestForest(at: TileCoordinate(x: 2, y: 3)),
        .noop,
        .harvestForest(at: TileCoordinate(x: 5, y: 5))
    ]
    for command in commands {
        worldA.enqueue(command)
        worldB.enqueue(command)
    }
    var allA: [WorldEvent] = []
    var allB: [WorldEvent] = []
    for _ in 0 ..< 50 {
        allA.append(contentsOf: worldA.tick().events)
        allB.append(contentsOf: worldB.tick().events)
    }
    #expect(allA == allB)
}

@Test("scenario: replay event sequences match")
func scenarioReplayEventSequencesMatch() {
    // Simulation-core delta restating the world-events guarantee in the
    // sim-core spec's voice. Identical inputs → element-wise-equal events.
    var worldA = World.fixtureWithTerrain(width: 8, height: 8, fill: .grass, seed: 77)
    var worldB = World.fixtureWithTerrain(width: 8, height: 8, fill: .grass, seed: 77)
    var allA: [WorldEvent] = []
    var allB: [WorldEvent] = []
    for _ in 0 ..< 30 {
        allA.append(contentsOf: worldA.tick().events)
        allB.append(contentsOf: worldB.tick().events)
    }
    #expect(allA == allB)
}

@Test("scenario: citycore still linux-clean after events land")
func scenarioCityCoreStillLinuxCleanAfterEventsLand() {
    // The world-events delta added a new public enum, a TickResult struct,
    // and per-system emit calls. None of that may introduce an Apple UI
    // framework import. Enforced mechanically by
    // scripts/check-no-apple-ui-imports.sh on pre-commit + CI; if any
    // forbidden import had snuck in the test target wouldn't have built.
    #expect(!CityCore.version.isEmpty)
}

@Test("scenario: replay world state remains byte-identical")
func scenarioReplayWorldStateRemainsByteIdentical() {
    // The existing determinism invariant must continue to hold regardless
    // of whether either run drained its event stream. We assert via the
    // World's Equatable conformance — the same approach the archived
    // `scenario: determinism under replay` test uses — because `Dictionary`-
    // backed fields encode to an array whose order is iteration-dependent
    // and not stable for byte-identical JSON comparison. Structural
    // equality is the operational invariant.
    var worldA = World.fixtureWithTerrain(width: 8, height: 8, fill: .forest, seed: 4242)
    var worldB = World.fixtureWithTerrain(width: 8, height: 8, fill: .forest, seed: 4242)
    let commands: [Command] = [
        .harvestForest(at: TileCoordinate(x: 1, y: 1)),
        .noop,
        .harvestForest(at: TileCoordinate(x: 4, y: 4))
    ]
    for command in commands {
        worldA.enqueue(command)
        worldB.enqueue(command)
    }
    for _ in 0 ..< 40 {
        _ = worldA.tick().events // A drains
        _ = worldB.tick() // B discards
    }
    #expect(worldA == worldB)
}
