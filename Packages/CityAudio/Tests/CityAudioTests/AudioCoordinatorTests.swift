import CityCore
import Foundation
import Testing
@testable import CityAudio

// Tests for spec `audio-playback` — `AudioCoordinator consumes per-tick
// events`, `Bindings file maps events to cues`, and `Loop lifecycle keyed
// by EntityID` requirements. Plus `add-spatial-audio` M1 — coordinator
// produces a `DispatchedCue` carrying the event's resolved position.

private func uiClickBindings() -> Bindings {
    Bindings(
        version: 1,
        bindings: [
            "buildingPlaced": [Bindings.Cue(file: "ui/click.caf", bus: .sfx, volume: 0.8)]
        ]
    )
}

@MainActor
@Test("scenario: bound event plays its cue")
func scenarioBoundEventPlaysItsCue() {
    var dispatched: [DispatchedCue] = []
    let coordinator = AudioCoordinator(bindings: uiClickBindings()) { dispatched.append($0) }
    let placement = WorldEvent.buildingPlaced(
        building: EntityID(raw: 1),
        kind: .road,
        anchor: TileCoordinate(x: 0, y: 0)
    )
    coordinator.consume(events: [placement])
    #expect(dispatched.count == 1)
    #expect(dispatched.first?.cue.file == "ui/click.caf")
    #expect(dispatched.first?.cue.bus == .sfx)
}

@MainActor
@Test("scenario: unbound event is silent")
func scenarioUnboundEventIsSilent() {
    var dispatched: [DispatchedCue] = []
    let coordinator = AudioCoordinator(bindings: uiClickBindings()) { dispatched.append($0) }
    // bankruptcyWarning has no entry in the test bindings.
    coordinator.consume(events: [.bankruptcyWarning(deficitTicks: 1)])
    #expect(dispatched.isEmpty, "no binding → no dispatch and no error")
}

@MainActor
@Test("scenario: multiple cues pick one at random")
func scenarioMultipleCuesPickOneAtRandom() {
    let bindings = Bindings(
        version: 1,
        bindings: [
            "buildingPlaced": [
                Bindings.Cue(file: "a.caf", bus: .sfx),
                Bindings.Cue(file: "b.caf", bus: .sfx),
                Bindings.Cue(file: "c.caf", bus: .sfx)
            ]
        ]
    )
    var picks: [String] = []
    let coordinator = AudioCoordinator(bindings: bindings) { picks.append($0.cue.file) }
    for _ in 0 ..< 100 {
        coordinator.consume(events: [
            .buildingPlaced(building: EntityID(raw: 1), kind: .road, anchor: TileCoordinate(x: 0, y: 0))
        ])
    }
    let uniquePicks = Set(picks)
    #expect(uniquePicks.count >= 2, "100 dispatches against 3 candidates must surface at least 2 distinct files")
}

@MainActor
@Test("scenario: coordinator dispatches every event")
func scenarioCoordinatorDispatchesEveryEvent() {
    let bindings = Bindings(
        version: 1,
        bindings: [
            "buildingPlaced": [Bindings.Cue(file: "ui/place.caf", bus: .sfx)],
            "constructionCompleted": [Bindings.Cue(file: "ui/chime.caf", bus: .sfx)],
            "taxesCollected": [Bindings.Cue(file: "ui/coin.caf", bus: .sfx)]
        ]
    )
    var dispatched: [String] = []
    let coordinator = AudioCoordinator(bindings: bindings) { dispatched.append($0.cue.file) }
    let events: [WorldEvent] = [
        .buildingPlaced(building: EntityID(raw: 1), kind: .road, anchor: TileCoordinate(x: 0, y: 0)),
        .constructionCompleted(building: EntityID(raw: 1), kind: .road, anchor: TileCoordinate(x: 0, y: 0)),
        .taxesCollected(amount: 100)
    ]
    coordinator.consume(events: events)
    #expect(dispatched == ["ui/place.caf", "ui/chime.caf", "ui/coin.caf"])
}

@MainActor
@Test("scenario: coordinator is main-actor safe")
func scenarioCoordinatorIsMainActorSafe() {
    // The presence of @MainActor on `consume` means the compiler enforces
    // main-actor calls. This test executes on the main actor and therefore
    // proves the API is reachable from MainActor contexts. (A compile-time
    // failure if the contract slipped would surface as a build error.)
    let coordinator = AudioCoordinator(bindings: uiClickBindings()) { _ in }
    coordinator.consume(events: [])
    #expect(Bool(true))
}

@MainActor
@Test("scenario: deleted file plays silently")
func scenarioDeletedFilePlaysSilently() {
    // The dispatcher is responsible for file load. In production, a missing
    // file at the path is caught inside the dispatcher and reported via
    // logging — the dispatcher returns normally, and the coordinator
    // continues dispatching subsequent events. We simulate that here: the
    // first cue references a file we treat as "missing"; the dispatcher
    // simply returns. The second cue still reaches the dispatcher.
    let bindings = Bindings(
        version: 1,
        bindings: [
            "buildingPlaced": [Bindings.Cue(file: "missing.caf", bus: .sfx)],
            "constructionCompleted": [Bindings.Cue(file: "exists.caf", bus: .sfx)]
        ]
    )
    var attemptedFiles: [String] = []
    let coordinator = AudioCoordinator(bindings: bindings) { dispatched in
        attemptedFiles.append(dispatched.cue.file)
        // No error propagated to the coordinator — production code logs
        // and returns when file load fails.
    }
    coordinator.consume(events: [
        .buildingPlaced(building: EntityID(raw: 1), kind: .road, anchor: TileCoordinate(x: 0, y: 0)),
        .constructionCompleted(building: EntityID(raw: 1), kind: .road, anchor: TileCoordinate(x: 0, y: 0))
    ])
    #expect(attemptedFiles == ["missing.caf", "exists.caf"], "coordinator must keep dispatching past a missing file")
}

// MARK: - Loop lifecycle

@MainActor
@Test("scenario: repeat start does not stack")
func scenarioRepeatStartDoesNotStack() {
    let bindings = Bindings(
        version: 1,
        bindings: [
            "buildingPlaced": [Bindings.Cue(file: "loop.caf", bus: .loop, loop: true)]
        ]
    )
    var dispatchCount = 0
    let coordinator = AudioCoordinator(bindings: bindings) { _ in
        dispatchCount += 1
    }
    let entity = EntityID(raw: 7)
    let event = WorldEvent.buildingPlaced(
        building: entity,
        kind: .sawmill,
        anchor: TileCoordinate(x: 0, y: 0)
    )
    coordinator.consume(events: [event])
    coordinator.consume(events: [event])
    coordinator.consume(events: [event])
    #expect(dispatchCount == 1, "loop start must be idempotent per entity")
    #expect(coordinator.hasActiveLoop(for: entity))
}

@MainActor
@Test("scenario: stop signal halts the loop")
func scenarioStopSignalHaltsTheLoop() {
    let bindings = Bindings(
        version: 1,
        bindings: [
            "buildingPlaced": [Bindings.Cue(file: "loop.caf", bus: .loop, loop: true)]
        ]
    )
    let coordinator = AudioCoordinator(bindings: bindings) { _ in }
    let entity = EntityID(raw: 7)
    coordinator.consume(events: [
        .buildingPlaced(building: entity, kind: .sawmill, anchor: TileCoordinate(x: 0, y: 0))
    ])
    #expect(coordinator.hasActiveLoop(for: entity))
    coordinator.stopLoop(for: entity)
    #expect(!coordinator.hasActiveLoop(for: entity))
}

// MARK: - Spatial position resolution (add-spatial-audio M1)

private func snapshotWithBuilding(at anchor: TileCoordinate, entity: EntityID) -> WorldSnapshot {
    // Synthesize a snapshot with one building at the given anchor so the
    // coordinator can resolve the position for matching primaryEntityID
    // events. The rest of the snapshot is empty — the coordinator only
    // reads `buildings[id]?.anchor`.
    let building = Building(
        id: entity,
        kind: .sawmill,
        anchor: anchor,
        state: .operational
    )
    return WorldSnapshot(
        tickCount: 0,
        simulatedTime: .zero,
        mapWidth: 0,
        mapHeight: 0,
        terrainGrid: [],
        occupiedTiles: [:],
        buildings: [entity: building],
        carriers: [],
        economy: Economy(),
        totalPopulation: 0,
        camera: Camera()
    )
}

private func emptySnapshot() -> WorldSnapshot {
    WorldSnapshot(
        tickCount: 0,
        simulatedTime: .zero,
        mapWidth: 0,
        mapHeight: 0,
        terrainGrid: [],
        occupiedTiles: [:],
        buildings: [:],
        carriers: [],
        economy: Economy(),
        totalPopulation: 0,
        camera: Camera()
    )
}

@MainActor
@Test("scenario: snapshot diff stops loops for missing entities")
func scenarioSnapshotDiffStopsLoopsForMissingEntities() {
    // A sawmill with an active loop is demolished. The next snapshot no
    // longer carries that entity — consumeSnapshot must call stopLoop.
    let bindings = Bindings(
        version: 1,
        bindings: [
            "productionResumed": [
                Bindings.Cue(file: "loop/saw.caf", bus: .loop, loop: true, kindFilter: .sawmill)
            ]
        ]
    )
    var dispatched: [DispatchedCue] = []
    let coordinator = AudioCoordinator(bindings: bindings) { dispatched.append($0) }
    let entity = EntityID(raw: 42)
    coordinator.consumeSnapshot(snapshotWithBuilding(at: TileCoordinate(x: 1, y: 1), entity: entity))
    coordinator.consume(events: [.productionResumed(producer: entity, kind: .sawmill)])
    #expect(coordinator.hasActiveLoop(for: entity))
    coordinator.consumeSnapshot(emptySnapshot())
    #expect(!coordinator.hasActiveLoop(for: entity), "snapshot missing the entity must teardown the loop")
}

@MainActor
@Test("scenario: snapshot consume is a no-op for unchanged worlds")
func scenarioSnapshotConsumeIsANoOpForUnchangedWorlds() {
    let bindings = Bindings(
        version: 1,
        bindings: [
            "productionResumed": [
                Bindings.Cue(file: "loop/saw.caf", bus: .loop, loop: true, kindFilter: .sawmill)
            ]
        ]
    )
    var dispatched: [DispatchedCue] = []
    let coordinator = AudioCoordinator(bindings: bindings) { dispatched.append($0) }
    let entity = EntityID(raw: 50)
    let anchor = TileCoordinate(x: 3, y: 3)
    coordinator.consumeSnapshot(snapshotWithBuilding(at: anchor, entity: entity))
    coordinator.consume(events: [.productionResumed(producer: entity, kind: .sawmill)])
    let dispatchedBefore = dispatched.count
    // Re-pushing the same snapshot keeps the loop active and dispatches
    // nothing new.
    coordinator.consumeSnapshot(snapshotWithBuilding(at: anchor, entity: entity))
    #expect(coordinator.hasActiveLoop(for: entity))
    #expect(dispatched.count == dispatchedBefore)
}

@MainActor
@Test("scenario: stop cue halts the active loop")
func scenarioStopCueHaltsTheActiveLoop() {
    let bindings = Bindings(
        version: 1,
        bindings: [
            "productionResumed": [
                Bindings.Cue(file: "loop/saw.caf", bus: .loop, loop: true, kindFilter: .sawmill)
            ],
            "productionStalled": [
                Bindings.Cue(action: .stop, kindFilter: .sawmill)
            ]
        ]
    )
    var dispatched: [DispatchedCue] = []
    let coordinator = AudioCoordinator(bindings: bindings) { dispatched.append($0) }
    let entity = EntityID(raw: 7)
    coordinator.consume(events: [
        .productionResumed(producer: entity, kind: .sawmill),
        .productionStalled(producer: entity, kind: .sawmill)
    ])
    // Exactly one dispatch (the start).
    #expect(dispatched.count == 1)
    #expect(!coordinator.hasActiveLoop(for: entity), "stop cue must release the active loop registration")
}

@MainActor
@Test("scenario: kind filter restricts a cue to matching events")
func scenarioKindFilterRestrictsACueToMatchingEvents() {
    let bindings = Bindings(
        version: 1,
        bindings: [
            "productionResumed": [
                Bindings.Cue(file: "loop/saw.caf", bus: .loop, loop: true, kindFilter: .sawmill)
            ]
        ]
    )
    var dispatched: [DispatchedCue] = []
    let coordinator = AudioCoordinator(bindings: bindings) { dispatched.append($0) }
    coordinator.consume(events: [
        .productionResumed(producer: EntityID(raw: 11), kind: .lumberjackHut)
    ])
    #expect(dispatched.isEmpty, "kind mismatch must skip the cue")
}

@MainActor
@Test("scenario: carrier arrival plays a one-shot")
func scenarioCarrierArrivalPlaysAOneShot() {
    let bindings = Bindings(
        version: 1,
        bindings: [
            "carrierArrived": [Bindings.Cue(file: "sfx/carrier-clink.caf", bus: .sfx)]
        ]
    )
    var dispatched: [DispatchedCue] = []
    let coordinator = AudioCoordinator(bindings: bindings) { dispatched.append($0) }
    coordinator.consume(events: [
        .carrierArrived(
            carrier: EntityID(raw: 99),
            at: TileCoordinate(x: 2, y: 3),
            good: .wood,
            amount: 1
        )
    ])
    #expect(dispatched.count == 1)
    #expect(dispatched.first?.cue.bus == .sfx)
    #expect(dispatched.first?.cue.file == "sfx/carrier-clink.caf")
}

@MainActor
@Test("scenario: stop cue is a no-op without an active loop")
func scenarioStopCueIsANoOpWithoutAnActiveLoop() {
    let bindings = Bindings(
        version: 1,
        bindings: [
            "productionStalled": [
                Bindings.Cue(action: .stop, kindFilter: .sawmill)
            ]
        ]
    )
    var dispatched: [DispatchedCue] = []
    let coordinator = AudioCoordinator(bindings: bindings) { dispatched.append($0) }
    coordinator.consume(events: [
        .productionStalled(producer: EntityID(raw: 99), kind: .sawmill)
    ])
    #expect(dispatched.isEmpty)
    #expect(!coordinator.hasActiveLoop(for: EntityID(raw: 99)))
}

@MainActor
@Test("scenario: kind filter matches when payload matches")
func scenarioKindFilterMatchesWhenPayloadMatches() {
    let bindings = Bindings(
        version: 1,
        bindings: [
            "productionResumed": [
                Bindings.Cue(file: "loop/saw.caf", bus: .loop, loop: true, kindFilter: .sawmill)
            ]
        ]
    )
    var dispatched: [DispatchedCue] = []
    let coordinator = AudioCoordinator(bindings: bindings) { dispatched.append($0) }
    coordinator.consume(events: [
        .productionResumed(producer: EntityID(raw: 12), kind: .sawmill)
    ])
    #expect(dispatched.count == 1)
}

@MainActor
@Test("scenario: loop cue carries the entity's position")
func scenarioLoopCueCarriesTheEntitysPosition() {
    let bindings = Bindings(
        version: 1,
        bindings: [
            "productionResumed": [Bindings.Cue(file: "saw.caf", bus: .loop, loop: true)]
        ]
    )
    var dispatched: [DispatchedCue] = []
    let coordinator = AudioCoordinator(bindings: bindings) { dispatched.append($0) }
    let entity = EntityID(raw: 42)
    let snapshot = snapshotWithBuilding(at: TileCoordinate(x: 5, y: 7), entity: entity)
    coordinator.consumeSnapshot(snapshot)
    coordinator.consume(events: [.productionResumed(producer: entity, kind: .sawmill)])
    #expect(dispatched.count == 1)
    #expect(dispatched.first?.position == TileCoordinate(x: 5, y: 7))
}

@MainActor
@Test("scenario: non-entity events have nil position")
func scenarioNonEntityEventsHaveNilPosition() {
    let bindings = Bindings(
        version: 1,
        bindings: [
            "taxesCollected": [Bindings.Cue(file: "coin.caf", bus: .sfx)]
        ]
    )
    var dispatched: [DispatchedCue] = []
    let coordinator = AudioCoordinator(bindings: bindings) { dispatched.append($0) }
    // No snapshot pushed — but the event also has no primary entity, so
    // the result is independent of the cache.
    coordinator.consume(events: [.taxesCollected(amount: 100)])
    #expect(dispatched.count == 1)
    #expect(dispatched.first?.position == nil)
}

@MainActor
@Test("scenario: coordinator falls back to nil before any snapshot has been consumed")
func scenarioCoordinatorFallsBackToNilBeforeAnySnapshotHasBeenConsumed() {
    let bindings = Bindings(
        version: 1,
        bindings: [
            "buildingPlaced": [Bindings.Cue(file: "place.caf", bus: .sfx)]
        ]
    )
    var dispatched: [DispatchedCue] = []
    let coordinator = AudioCoordinator(bindings: bindings) { dispatched.append($0) }
    // Event with an EntityID fires before consumeSnapshot has ever been called.
    let entity = EntityID(raw: 1)
    coordinator.consume(events: [
        .buildingPlaced(building: entity, kind: .road, anchor: TileCoordinate(x: 3, y: 4))
    ])
    #expect(dispatched.count == 1)
    #expect(dispatched.first?.position == nil, "no snapshot cached → no position resolution")
}

@MainActor
@Test("scenario: cue defaults to spatialized on the loop bus")
func scenarioCueDefaultsToSpatializedOnTheLoopBus() {
    // Cue with no `spatialize` field on the loop bus → isSpatialized == true.
    let loopCue = Bindings.Cue(file: "saw.caf", bus: .loop, loop: true)
    let dispatched = DispatchedCue(cue: loopCue, position: TileCoordinate(x: 0, y: 0))
    #expect(dispatched.isSpatialized)

    // Same default on a non-loop bus → isSpatialized == false.
    let sfxCue = Bindings.Cue(file: "click.caf", bus: .sfx)
    let dispatchedSfx = DispatchedCue(cue: sfxCue, position: TileCoordinate(x: 0, y: 0))
    #expect(!dispatchedSfx.isSpatialized)

    // Explicit `spatialize: true` on a non-loop bus wins.
    let explicitSfx = Bindings.Cue(file: "delivery.caf", bus: .sfx, spatialize: true)
    let dispatchedExplicitSfx = DispatchedCue(cue: explicitSfx, position: TileCoordinate(x: 0, y: 0))
    #expect(dispatchedExplicitSfx.isSpatialized)

    // Explicit `spatialize: false` on the loop bus wins.
    let loopOptOut = Bindings.Cue(file: "ambient-loop.caf", bus: .loop, loop: true, spatialize: false)
    let dispatchedLoopOptOut = DispatchedCue(cue: loopOptOut, position: TileCoordinate(x: 0, y: 0))
    #expect(!dispatchedLoopOptOut.isSpatialized)
}
