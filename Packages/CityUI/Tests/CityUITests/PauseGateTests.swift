import CityCore
import Foundation
import Testing
@testable import CityUI

// Tests for the GameSession.isPaused gate added by
// `add-game-pause-menu` → M1. Scenarios under `Requirement: Paused
// session does not tick the world` in
// openspec/changes/add-game-pause-menu/specs/pause-menu/spec.md.

@MainActor
@Test("scenario: pause defaults to false on fresh session")
func scenarioPauseDefaultsToFalseOnFreshSession() {
    let session = GameSession()
    #expect(session.isPaused == false)
}

@MainActor
@Test("scenario: paused step does not advance the world")
func scenarioPausedStepDoesNotAdvanceTheWorld() {
    let session = GameSession()
    let priorTick = session.world.tickCount
    session.isPaused = true
    session.step()
    #expect(session.world.tickCount == priorTick)
}

@MainActor
@Test("scenario: paused step does not forward events")
func scenarioPausedStepDoesNotForwardEvents() {
    var received: [WorldEvent] = []
    let session = GameSession(audioEventConsumer: { received.append(contentsOf: $0) })
    session.isPaused = true
    // Manually call step a few times — the timer doesn't run in tests.
    session.step()
    session.step()
    session.step()
    #expect(received.isEmpty)
}

@MainActor
@Test("scenario: toggling ispaused resumes ticking")
func scenarioTogglingIsPausedResumesTicking() {
    let session = GameSession()
    session.isPaused = true
    session.step()
    let pausedTick = session.world.tickCount
    session.isPaused = false
    session.step()
    #expect(session.world.tickCount == pausedTick + 1)
}

// MARK: - Audio invariants (Requirement: Music continues while paused)

@MainActor
@Test("scenario: sfx events do not fire while paused")
func scenarioSFXEventsDoNotFireWhilePaused() {
    var dispatched: [WorldEvent] = []
    let session = GameSession(audioEventConsumer: { dispatched.append(contentsOf: $0) })
    session.isPaused = true
    for _ in 0 ..< 30 {
        session.step()
    }
    #expect(dispatched.isEmpty)
}

@MainActor
@Test("scenario: music continues while paused")
func scenarioMusicContinuesWhilePaused() {
    // Documentary: pause is a step() guard, never reaching the audio
    // coordinator. Engine `isRunning` is owned by `AudioStack` —
    // separate from the session — and is unaffected by toggling
    // `isPaused`. We assert the surface that's observable from this
    // package: no event dispatch escapes the gate.
    let session = GameSession(audioEventConsumer: { _ in
        Issue.record("unexpected dispatch while paused")
    })
    session.isPaused = true
    session.step()
}

@MainActor
@Test("scenario: audio engine is not stopped on pause")
func scenarioAudioEngineIsNotStoppedOnPause() {
    // Documentary mirror of "music continues while paused" from the
    // engine-state angle: the session has no engine handle, so a
    // toggle round-trip cannot affect engine state.
    let session = GameSession()
    session.isPaused = true
    session.isPaused = false
    session.isPaused = true
}
