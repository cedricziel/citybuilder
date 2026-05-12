import CityCore
import Foundation

/// Top-level wiring of the audio layer. App shells construct one of these
/// at launch and pass `consume(events:)` into `GameSession`. The stack
/// orchestrates:
///
/// - `AudioEngine` — AVAudioEngine wrapper with four mixer buses.
/// - `AudioSettings` — persisted volumes + mute, observable.
/// - `PlatformAudioSession` — iOS audio-session category + interruption.
/// - `Manifest` + `Bindings` — loaded from the resource bundle.
/// - `EngineCuePlayer` — real cue dispatcher backed by AVAudioPlayerNode.
/// - `AudioCoordinator` — routes per-tick `[WorldEvent]` through bindings.
///
/// Per design D12 (single integration point): app shells only need to
/// touch `AudioStack`; everything else is internal wiring.
@MainActor
public final class AudioStack {
    public let engine: AudioEngine
    public let settings: AudioSettings
    public let session: PlatformAudioSession
    public let manifest: Manifest
    public let bindings: Bindings
    public let player: EngineCuePlayer
    public let coordinator: AudioCoordinator

    public init(bundle: Bundle = .main, userDefaults: UserDefaults = .standard) {
        let manifest = AudioBundleLoader.loadManifest(in: bundle)
        let bindings = AudioBundleLoader.loadBindings(manifest: manifest, in: bundle)
        let engine = AudioEngine()
        let settings = AudioSettings(userDefaults: userDefaults)
        let session = PlatformAudioSession(engine: engine)
        let player = EngineCuePlayer(engine: engine, bundle: bundle)

        // Apply persisted volumes to the engine buses.
        engine.setVolume(settings.musicVolume, on: .music)
        engine.setVolume(settings.sfxVolume, on: .sfx)
        engine.setVolume(settings.sfxVolume, on: .ambient)
        engine.setVolume(settings.musicVolume, on: .loop)
        engine.isMuted = settings.isMuted

        let coordinator = AudioCoordinator(bindings: bindings) { [weak player] cue in
            player?.play(cue)
        }

        self.manifest = manifest
        self.bindings = bindings
        self.engine = engine
        self.settings = settings
        self.session = session
        self.player = player
        self.coordinator = coordinator
    }

    /// Forward per-tick events from `GameSession` into the coordinator.
    /// Also lazy-activates the platform audio session on the first call.
    public func consume(events: [WorldEvent]) {
        if !session.isActivated, !events.isEmpty {
            try? session.activate()
        }
        coordinator.consume(events: events)
    }
}
