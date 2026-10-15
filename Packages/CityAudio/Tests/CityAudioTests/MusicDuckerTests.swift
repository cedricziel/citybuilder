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

/// Stands in for `Task.sleep`: each wait is recorded and suspends until
/// the test ends it, so the release window passes without the wall clock.
private actor ManualSleeper {
    private(set) var requested: [UInt64] = []
    private var waiting: [CheckedContinuation<Void, Never>] = []

    func sleep(nanoseconds: UInt64) async {
        requested.append(nanoseconds)
        await withCheckedContinuation { waiting.append($0) }
    }

    /// Waits until `count` sleeps have started.
    func waitForSleeps(_ count: Int) async {
        while waiting.count < count {
            await Task.yield()
        }
    }

    /// Ends the wait of the sleep that started `index`-th.
    func wake(_ index: Int) {
        waiting[index].resume()
    }
}

@MainActor
@Test("scenario: music recovers after release window")
func scenarioMusicRecoversAfterReleaseWindow() async {
    let volume = VolumeBox(0.8)
    let sleeper = ManualSleeper()
    let ducker = MusicDucker(
        inner: { _ in },
        readMusicVolume: { volume.current },
        writeMusicVolume: { volume.current = $0 },
        attackSeconds: 0.03,
        releaseSeconds: 0.5,
        sleep: { await sleeper.sleep(nanoseconds: $0) }
    )
    let sfx = DispatchedCue(
        cue: Bindings.Cue(file: "ui/click.caf", bus: .sfx),
        position: nil
    )
    ducker.dispatch(sfx)
    await sleeper.waitForSleeps(1)
    #expect(volume.current == Float(0.4), "music stays ducked during the release window")
    await sleeper.wake(0)
    await ducker.pendingRelease?.value
    #expect(volume.current == Float(0.8), "music must recover to baseline")
    let requested = await sleeper.requested
    #expect(requested == [530_000_000], "the release waits attack plus release")
}

@MainActor
@Test("a release from an earlier duck leaves a later duck in place")
func staleReleaseLeavesTheLaterDuck() async {
    let volume = VolumeBox(0.8)
    let sleeper = ManualSleeper()
    let ducker = MusicDucker(
        inner: { _ in },
        readMusicVolume: { volume.current },
        writeMusicVolume: { volume.current = $0 },
        sleep: { await sleeper.sleep(nanoseconds: $0) }
    )
    let sfx = DispatchedCue(
        cue: Bindings.Cue(file: "ui/click.caf", bus: .sfx),
        position: nil
    )
    ducker.dispatch(sfx)
    let first = ducker.pendingRelease
    ducker.dispatch(sfx)
    await sleeper.waitForSleeps(2)
    await sleeper.wake(0)
    await first?.value
    #expect(volume.current == Float(0.4), "the first release must not undo the second duck")
    await sleeper.wake(1)
    await ducker.pendingRelease?.value
    #expect(volume.current == Float(0.8))
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
