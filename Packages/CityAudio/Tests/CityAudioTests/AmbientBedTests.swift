import CityCore
import Foundation
import Testing
@testable import CityAudio

// Tests for spec `audio-playback` — `Ambient bed section` requirement
// (`enrich-audio-world` M6).

@MainActor
@Test("scenario: ambient track starts on first non-empty events")
func scenarioAmbientTrackStartsOnFirstNonEmptyEvents() {
    let bindings = Bindings(
        version: 1,
        bindings: [:],
        ambient: Bindings.AmbientSection(
            tracks: [Bindings.MusicTrack(file: "ambient/forest-birds.caf")]
        )
    )
    var dispatched: [DispatchedCue] = []
    let bed = AmbientBed(section: bindings.ambient) { dispatched.append($0) }
    bed.consume(events: [.taxesCollected(amount: 1)])
    #expect(dispatched.count == 1)
    let cue = dispatched.first?.cue
    #expect(cue?.bus == .ambient)
    #expect(cue?.loop == true)
    #expect(cue?.file == "ambient/forest-birds.caf")
}

@MainActor
@Test("scenario: ambient track loops indefinitely")
func scenarioAmbientTrackLoopsIndefinitely() {
    // The bed must mark the ambient cue as a loop so the engine player
    // re-schedules it on completion. (The engine-side loop scheduling is
    // exercised by `EngineCuePlayer` tests; this confirms the bed sets
    // the `loop: true` flag the player keys off.)
    let bindings = Bindings(
        version: 1,
        bindings: [:],
        ambient: Bindings.AmbientSection(
            tracks: [Bindings.MusicTrack(file: "ambient/forest-birds.caf")]
        )
    )
    var dispatched: [DispatchedCue] = []
    let bed = AmbientBed(section: bindings.ambient) { dispatched.append($0) }
    bed.consume(events: [.taxesCollected(amount: 1)])
    #expect(dispatched.first?.cue.loop == true)
}

@MainActor
@Test("scenario: ambient track is idempotent across multiple ticks")
func scenarioAmbientTrackIsIdempotentAcrossMultipleTicks() {
    let bindings = Bindings(
        version: 1,
        bindings: [:],
        ambient: Bindings.AmbientSection(
            tracks: [Bindings.MusicTrack(file: "ambient/forest-birds.caf")]
        )
    )
    var dispatched: [DispatchedCue] = []
    let bed = AmbientBed(section: bindings.ambient) { dispatched.append($0) }
    bed.consume(events: [.taxesCollected(amount: 1)])
    bed.consume(events: [.taxesCollected(amount: 2)])
    bed.consume(events: [.taxesCollected(amount: 3)])
    #expect(dispatched.count == 1, "ambient cue must only fire once over multiple ticks")
}

@MainActor
@Test("scenario: empty ambient section is a no-op")
func scenarioEmptyAmbientSectionIsANoOp() {
    var dispatched: [DispatchedCue] = []
    let bed = AmbientBed(section: nil) { dispatched.append($0) }
    bed.consume(events: [.taxesCollected(amount: 1)])
    #expect(dispatched.isEmpty)

    var dispatched2: [DispatchedCue] = []
    let empty = Bindings.AmbientSection(tracks: [])
    let bed2 = AmbientBed(section: empty) { dispatched2.append($0) }
    bed2.consume(events: [.taxesCollected(amount: 1)])
    #expect(dispatched2.isEmpty)
}

@MainActor
@Test("scenario: ambient is silent until the first event arrives")
func scenarioAmbientIsSilentUntilTheFirstEventArrives() {
    // An empty events array (the typical "nothing happened this tick"
    // case) must not start ambient. Only the first non-empty tick does.
    let bindings = Bindings(
        version: 1,
        bindings: [:],
        ambient: Bindings.AmbientSection(
            tracks: [Bindings.MusicTrack(file: "ambient/forest-birds.caf")]
        )
    )
    var dispatched: [DispatchedCue] = []
    let bed = AmbientBed(section: bindings.ambient) { dispatched.append($0) }
    bed.consume(events: [])
    #expect(dispatched.isEmpty)
    bed.consume(events: [.taxesCollected(amount: 1)])
    #expect(dispatched.count == 1)
}
