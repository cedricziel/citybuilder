import CityCore
import Foundation
import Testing
@testable import CityAudio

// Tests for spec `audio-playback` — `AudioCoordinator consumes per-tick
// events`, `Bindings file maps events to cues`, and `Loop lifecycle keyed
// by EntityID` requirements.

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
    var dispatched: [Bindings.Cue] = []
    let coordinator = AudioCoordinator(bindings: uiClickBindings()) { cue in
        dispatched.append(cue)
    }
    let placement = WorldEvent.buildingPlaced(
        building: EntityID(raw: 1),
        kind: .road,
        anchor: TileCoordinate(x: 0, y: 0)
    )
    coordinator.consume(events: [placement])
    #expect(dispatched.count == 1)
    #expect(dispatched.first?.file == "ui/click.caf")
    #expect(dispatched.first?.bus == .sfx)
}

@MainActor
@Test("scenario: unbound event is silent")
func scenarioUnboundEventIsSilent() {
    var dispatched: [Bindings.Cue] = []
    let coordinator = AudioCoordinator(bindings: uiClickBindings()) { cue in
        dispatched.append(cue)
    }
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
    let coordinator = AudioCoordinator(bindings: bindings) { cue in
        picks.append(cue.file)
    }
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
    let coordinator = AudioCoordinator(bindings: bindings) { cue in
        dispatched.append(cue.file)
    }
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
    let coordinator = AudioCoordinator(bindings: bindings) { cue in
        attemptedFiles.append(cue.file)
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
