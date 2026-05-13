import AVFoundation
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
        // iOS pre-configures the AVAudioSession before AVAudioEngine() so the
        // engine's session association at construction finds a valid session
        // rather than logging -10879 and entering a degraded state. macOS
        // no-op. The PlatformAudioSession instance below still does its own
        // activate() to install the interruption observer.
        PlatformAudioSession.configureSessionEarly()
        let settings = AudioSettings(userDefaults: userDefaults)
        let engine = AudioEngine(spatialEnabled: settings.spatialAudioEnabled)
        // Apply persisted distance attenuation (no-op when spatial is off).
        engine.setSpatialDistances(
            reference: settings.spatialReferenceDistance,
            max: settings.spatialMaxDistance
        )
        let session = PlatformAudioSession(engine: engine)
        let player = EngineCuePlayer(engine: engine, bundle: bundle)

        // Apply persisted volumes to the engine buses.
        engine.setVolume(settings.musicVolume, on: .music)
        engine.setVolume(settings.sfxVolume, on: .sfx)
        engine.setVolume(settings.sfxVolume, on: .ambient)
        engine.setVolume(settings.musicVolume, on: .loop)
        engine.isMuted = settings.isMuted

        let coordinator = AudioCoordinator(bindings: bindings) { [weak player] dispatched in
            player?.play(dispatched)
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
        // Attach the interruption observer (and re-confirm session category
        // on iOS — idempotent). configureSessionEarly() above already did
        // the heavy lifting; this just brings PlatformAudioSession's
        // bookkeeping in sync.
        try? session.activate()
        // Start music immediately if a track is bound. The previous "wait
        // for first event" gate didn't survive contact with iOS — without
        // engine warmup, no audio plays until the player triggers an event,
        // which on a fresh empty island can take ~5 seconds (tax interval).
        startMusicIfAvailable()
    }

    /// Push the current local audio settings to the cloud store, if any.
    /// Call from the Settings UI after the user changes a slider or toggle.
    public func syncSettingsToCloud() async {
        await settingsSync?.pushLocalToCloud()
    }

    /// Forward per-tick events from `GameSession` into the coordinator.
    /// Session activation and music start happen at init now (iOS audio
    /// engine semantics require it); this just routes events.
    public func consume(events: [WorldEvent]) {
        coordinator.consume(events: events)
    }

    /// Forward the per-tick `WorldSnapshot` into the coordinator so it can
    /// resolve each event's primary entity to a `TileCoordinate` for the
    /// spatial layer. Call this immediately before `consume(events:)` for
    /// the same tick. Snapshots before any events are valid — the cached
    /// snapshot is just used for entity lookups.
    public func consumeSnapshot(_ snapshot: WorldSnapshot) {
        coordinator.consumeSnapshot(snapshot)
    }

    /// Write the listener's tile-space position to the environment node.
    /// Called by the renderer at most once per second. No-op if spatial
    /// audio is disabled (no environment node) or if `tile` is nil.
    /// Per spec `audio-playback` "Listener position from camera".
    public func setListenerPosition(_ tile: TileCoordinate?) {
        guard let env = engine.environmentNode, let tile else { return }
        env.listenerPosition = AVAudio3DPoint(x: Float(tile.x), y: 0, z: Float(tile.y))
    }

    /// Picks the next track from the playlist (if any) and starts looping
    /// it on the music bus. Idempotent — calling more than once during a
    /// single track's lifetime is a no-op.
    public func startMusicIfAvailable() {
        guard !musicStarted, let track = playlist.nextTrack() else { return }
        musicStarted = true
        let cue = Bindings.Cue(file: track.file, bus: .music, volume: nil, loop: true)
        player.play(DispatchedCue(cue: cue, position: nil))
    }
}
