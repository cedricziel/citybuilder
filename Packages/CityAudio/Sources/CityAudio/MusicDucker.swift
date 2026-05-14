import Foundation

/// Volume-ducker that sits between `AudioCoordinator` and the production
/// `EngineCuePlayer`. Every cue still flows through, but SFX cues
/// additionally pull the `music` mixer's `outputVolume` down to half its
/// configured level for a short window and ramp it back up. Per spec
/// `audio-playback` — Music ducking.
///
/// Reentrant: overlapping SFX cues restart the release timer rather than
/// stacking reductions, so a 5-shot burst still only ducks once.
@MainActor
public final class MusicDucker {
    public typealias VolumeReader = @MainActor () -> Float
    public typealias VolumeWriter = @MainActor (Float) -> Void

    private let inner: AudioCoordinator.CueDispatcher
    private let readMusicVolume: VolumeReader
    private let writeMusicVolume: VolumeWriter
    private let attackSeconds: Double
    private let releaseSeconds: Double
    /// Linear gain applied during the ducked window. 0.5 ≈ −6 dB.
    private let duckFactor: Float
    /// Baseline volume to restore after release. Captured at the start of
    /// the first duck so the player's slider position survives the ramp.
    private var savedVolume: Float?
    /// Generation counter: each duck bumps it so any in-flight release
    /// task from a prior duck recognises it is stale and skips the restore.
    private var generation: UInt64 = 0

    public init(
        inner: @escaping AudioCoordinator.CueDispatcher,
        readMusicVolume: @escaping VolumeReader,
        writeMusicVolume: @escaping VolumeWriter,
        attackSeconds: Double = 0.03,
        releaseSeconds: Double = 0.30,
        duckFactor: Float = 0.5
    ) {
        self.inner = inner
        self.readMusicVolume = readMusicVolume
        self.writeMusicVolume = writeMusicVolume
        self.attackSeconds = attackSeconds
        self.releaseSeconds = releaseSeconds
        self.duckFactor = duckFactor
    }

    /// Drop-in replacement for `AudioCoordinator.CueDispatcher`. Pass this
    /// when constructing the coordinator so every dispatched cue passes
    /// through the ducker first.
    public func dispatch(_ dispatched: DispatchedCue) {
        if dispatched.cue.bus == .sfx {
            duck()
        }
        inner(dispatched)
    }

    private func duck() {
        if savedVolume == nil {
            savedVolume = readMusicVolume()
        }
        let baseline = savedVolume ?? readMusicVolume()
        writeMusicVolume(baseline * duckFactor)
        generation &+= 1
        let myGen = generation
        let releaseNs = UInt64(max(0, attackSeconds + releaseSeconds) * 1_000_000_000)
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: releaseNs)
            guard let self else { return }
            guard self.generation == myGen else { return }
            if let saved = self.savedVolume {
                self.writeMusicVolume(saved)
                self.savedVolume = nil
            }
        }
    }
}
