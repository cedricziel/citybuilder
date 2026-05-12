import CityCore
import CityPersistence
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
    public let playlist: MusicPlaylist
    /// Optional iCloud sync layer. Non-nil when the app shell passes a
    /// `CloudKeyValueStore` (typically `UbiquitousAudioSettingsStore` in
    /// production). The settings model writes through to UserDefaults
    /// either way — the sync layer only mirrors to iCloud.
    public let settingsSync: AudioSettingsSync?
    private var musicStarted = false

    public init(
        bundle: Bundle = .main,
        userDefaults: UserDefaults = .standard,
        cloudStore: CloudKeyValueStore? = nil
    ) {
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

        let playlist = MusicPlaylist(
            tracks: bindings.music?.tracks ?? [],
            gapSecondsBetweenTracks: bindings.music?.gapSecondsBetweenTracks
                ?? MusicPlaylist.defaultGapSeconds
        )

        self.manifest = manifest
        self.bindings = bindings
        self.engine = engine
        self.settings = settings
        self.session = session
        self.player = player
        self.coordinator = coordinator
        self.playlist = playlist
        self.settingsSync = cloudStore.map { AudioSettingsSync(store: $0, defaults: userDefaults) }
        // Pull any cloud-stored values into UserDefaults at launch so the
        // engine starts with the latest cross-device volumes.
        if let sync = settingsSync {
            Task { await sync.pullCloudToLocal() }
        }
    }

    /// Push the current local audio settings to the cloud store, if any.
    /// Call from the Settings UI after the user changes a slider or toggle.
    public func syncSettingsToCloud() async {
        await settingsSync?.pushLocalToCloud()
    }

    /// Forward per-tick events from `GameSession` into the coordinator.
    /// Also lazy-activates the platform audio session and starts the music
    /// loop on the first call.
    public func consume(events: [WorldEvent]) {
        if !session.isActivated, !events.isEmpty {
            try? session.activate()
            startMusicIfAvailable()
        }
        coordinator.consume(events: events)
    }

    /// Picks the next track from the playlist (if any) and starts looping
    /// it on the music bus. Idempotent — calling more than once during a
    /// single track's lifetime is a no-op.
    public func startMusicIfAvailable() {
        guard !musicStarted, let track = playlist.nextTrack() else { return }
        musicStarted = true
        let cue = Bindings.Cue(file: track.file, bus: .music, volume: nil, loop: true)
        player.play(cue)
    }
}
