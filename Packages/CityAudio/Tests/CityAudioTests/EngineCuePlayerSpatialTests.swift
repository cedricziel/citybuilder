import AVFoundation
import CityCore
import Foundation
import Testing
@testable import CityAudio

// Tests for spec `audio-playback` "Spatialized loop playback"
// (`add-spatial-audio` M3). Exercises the pure routing helper so we
// don't need a bundled audio file for these checks.

@Test("scenario: spatialized loop applies the cue position to the player")
func scenarioSpatializedLoopAppliesTheCuePositionToThePlayer() {
    // A loop-bus cue with no explicit `spatialize` flag defaults to
    // spatialized. With a resolved position and the environment node
    // available, the routing decision points at the env node and carries
    // a 3D point matching the tile (x, 0, y).
    let cue = Bindings.Cue(file: "saw.caf", bus: .loop, loop: true)
    let dispatched = DispatchedCue(cue: cue, position: TileCoordinate(x: 8, y: 3))
    let routing = EngineCuePlayer.loopRouting(for: dispatched, environmentAvailable: true)
    #expect(routing.target == .environmentNode)
    #expect(routing.position?.x == 8)
    #expect(routing.position?.y == 0)
    #expect(routing.position?.z == 3)
}

@Test("scenario: unspatialized cue ignores position")
func scenarioUnspatializedCueIgnoresPosition() {
    // Explicit opt-out on a loop cue: must route through the loop mixer
    // and carry no position, even though one was resolved.
    let cue = Bindings.Cue(file: "ambient-loop.caf", bus: .loop, loop: true, spatialize: false)
    let dispatched = DispatchedCue(cue: cue, position: TileCoordinate(x: 8, y: 3))
    let routing = EngineCuePlayer.loopRouting(for: dispatched, environmentAvailable: true)
    #expect(routing.target == .loopMixer)
    #expect(routing.position == nil)
}

@Test("scenario: cue defaults to spatialized routing on the loop bus")
func scenarioCueDefaultsToSpatializedRoutingOnTheLoopBus() {
    // A non-loop cue (e.g. sfx) does not get spatial routing even with
    // a position; the env node is for loops only by default.
    let sfxCue = Bindings.Cue(file: "click.caf", bus: .sfx)
    let dispatchedSfx = DispatchedCue(cue: sfxCue, position: TileCoordinate(x: 5, y: 5))
    let routingSfx = EngineCuePlayer.loopRouting(for: dispatchedSfx, environmentAvailable: true)
    #expect(routingSfx.target == .loopMixer)
    #expect(routingSfx.position == nil)

    // A loop cue, even without explicit spatialize, routes to env when
    // env is available + a position is resolved.
    let loopCue = Bindings.Cue(file: "saw.caf", bus: .loop, loop: true)
    let dispatchedLoop = DispatchedCue(cue: loopCue, position: TileCoordinate(x: 1, y: 2))
    let routingLoop = EngineCuePlayer.loopRouting(for: dispatchedLoop, environmentAvailable: true)
    #expect(routingLoop.target == .environmentNode)
}

@Test("loop routing falls back to mixer when environment is absent")
func loopRoutingFallsBackToMixerWhenEnvironmentIsAbsent() {
    // When spatial is disabled at the engine level, even a spatializable
    // loop cue with a position falls back to the loop mixer path. The
    // alternative (writing position to a non-spatial mixer) would set
    // the property uselessly.
    let cue = Bindings.Cue(file: "saw.caf", bus: .loop, loop: true)
    let dispatched = DispatchedCue(cue: cue, position: TileCoordinate(x: 8, y: 3))
    let routing = EngineCuePlayer.loopRouting(for: dispatched, environmentAvailable: false)
    #expect(routing.target == .loopMixer)
    #expect(routing.position == nil)
}

@Test("loop routing falls back to mixer when no position is resolved")
func loopRoutingFallsBackToMixerWhenNoPositionIsResolved() {
    // A loop cue intended for spatial routing but with no resolved
    // position (event fired before any snapshot) falls back to the loop
    // mixer rather than spatializing at the origin (which would imply
    // "co-located with the listener" — misleading).
    let cue = Bindings.Cue(file: "saw.caf", bus: .loop, loop: true)
    let dispatched = DispatchedCue(cue: cue, position: nil)
    let routing = EngineCuePlayer.loopRouting(for: dispatched, environmentAvailable: true)
    #expect(routing.target == .loopMixer)
    #expect(routing.position == nil)
}
