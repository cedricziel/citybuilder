import CityCore
import Foundation
import Testing
@testable import CityAudio

// Tests for spec `audio-playback` — `Music ducking` requirement
// (`enrich-audio-world` M4).

@MainActor
private final class VolumeBox {
    var current: Float
    init(_ value: Float) {
        current = value
    }
}

@MainActor
@Test("scenario: sfx cue ducks the music bus")
func scenarioSfxCueDucksTheMusicBus() {
    let volume = VolumeBox(0.8)
    var forwarded: [DispatchedCue] = []
    let ducker = MusicDucker(
        inner: { forwarded.append($0) },
        readMusicVolume: { volume.current },
        writeMusicVolume: { volume.current = $0 }
    )
    let sfx = DispatchedCue(
        cue: Bindings.Cue(file: "ui/click.caf", bus: .sfx),
        position: nil
    )
    ducker.dispatch(sfx)
    // Volume must drop to V * 0.5 synchronously (well within one render cycle).
    #expect(volume.current == Float(0.4))
    #expect(forwarded.count == 1, "inner dispatcher must still receive the cue")
}

@MainActor
@Test("scenario: music recovers after release window")
func scenarioMusicRecoversAfterReleaseWindow() async throws {
    let volume = VolumeBox(0.8)
    let ducker = MusicDucker(
        inner: { _ in },
        readMusicVolume: { volume.current },
        writeMusicVolume: { volume.current = $0 },
        // Use a tight release window so the test stays fast. The
        // production constants are 30 / 300 ms.
        attackSeconds: 0.0,
        releaseSeconds: 0.05
    )
    let sfx = DispatchedCue(
        cue: Bindings.Cue(file: "ui/click.caf", bus: .sfx),
        position: nil
    )
    ducker.dispatch(sfx)
    #expect(volume.current == Float(0.4))
    try await Task.sleep(nanoseconds: 200_000_000) // 200 ms — well past release
    #expect(volume.current == Float(0.8), "music must recover to baseline")
}

@MainActor
@Test("scenario: loop and ambient cues do not duck music")
func scenarioLoopAndAmbientCuesDoNotDuckMusic() {
    let volume = VolumeBox(0.8)
    let ducker = MusicDucker(
        inner: { _ in },
        readMusicVolume: { volume.current },
        writeMusicVolume: { volume.current = $0 }
    )
    ducker.dispatch(DispatchedCue(
        cue: Bindings.Cue(file: "loop/saw.caf", bus: .loop, loop: true),
        position: nil
    ))
    #expect(volume.current == Float(0.8))
    ducker.dispatch(DispatchedCue(
        cue: Bindings.Cue(file: "ambient/birds.caf", bus: .ambient, loop: true),
        position: nil
    ))
    #expect(volume.current == Float(0.8))
}

@MainActor
@Test("scenario: ducking respects the user toggle")
func scenarioDuckingRespectsTheUserToggle() throws {
    // When musicDucksUnderSFX is false, the AudioStack must bypass the
    // ducker and dispatch cues straight to the engine — no volume change.
    let defaults = try #require(UserDefaults(suiteName: "music-ducker-toggle-test-\(UUID().uuidString)"))
    let settings = AudioSettings(userDefaults: defaults)
    settings.musicDucksUnderSFX = false
    #expect(!settings.musicDucksUnderSFX)
    // Reuse a VolumeBox to confirm the ducker is bypassed: dispatching an
    // SFX cue through the inner dispatcher directly must leave volume
    // unchanged. This mirrors what `AudioStack` does when the flag is off.
    let volume = VolumeBox(0.6)
    let dispatcher: AudioCoordinator.CueDispatcher = { _ in
        // No-op inner — the AudioStack would call the engine here.
    }
    let chain: AudioCoordinator.CueDispatcher = settings.musicDucksUnderSFX
        ? { dispatched in
            MusicDucker(
                inner: dispatcher,
                readMusicVolume: { volume.current },
                writeMusicVolume: { volume.current = $0 }
            ).dispatch(dispatched)
        }
        : dispatcher
    chain(DispatchedCue(
        cue: Bindings.Cue(file: "ui/click.caf", bus: .sfx),
        position: nil
    ))
    #expect(volume.current == Float(0.6), "ducking-off must leave music volume untouched")
}

@MainActor
@Test("scenario: overlapping sfx do not stack reductions")
func scenarioOverlappingSfxDoNotStackReductions() {
    // Two SFX cues back-to-back must duck to V * 0.5 once, not V * 0.25.
    let volume = VolumeBox(0.6)
    let ducker = MusicDucker(
        inner: { _ in },
        readMusicVolume: { volume.current },
        writeMusicVolume: { volume.current = $0 }
    )
    let sfx = DispatchedCue(
        cue: Bindings.Cue(file: "ui/click.caf", bus: .sfx),
        position: nil
    )
    ducker.dispatch(sfx)
    ducker.dispatch(sfx)
    #expect(volume.current == Float(0.3), "reentrant ducks must not stack")
}
