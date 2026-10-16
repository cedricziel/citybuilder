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
    public let music: MusicDirector
    public let ambientBed: AmbientBed
    /// Seasonal and coastal beds, when the bindings name them.
    public let ambientScene: AmbientScene?
    /// Optional iCloud sync layer. Non-nil when the app shell passes a
    /// `CloudKeyValueStore` (typically `UbiquitousAudioSettingsStore` in
    /// production). The settings model writes through to UserDefaults
    /// either way — the sync layer only mirrors to iCloud.
    public let settingsSync: AudioSettingsSync?
    private var clock: Timer?

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

        Self.applyVolumes(settings, to: engine)

        // Production dispatcher: route every dispatched cue to the cue
        // player. When music ducking is enabled, wrap the player in a
        // `MusicDucker` so SFX cues briefly dip the music bus. The flag
        // is read once at construction; toggling at runtime requires a
        // stack rebuild (intentional — same shape as spatial audio).
        let playDispatcher: AudioCoordinator.CueDispatcher = { [weak player] dispatched in
            player?.play(dispatched)
        }
        let dispatcher: AudioCoordinator.CueDispatcher
        if settings.musicDucksUnderSFX {
            let ducker = MusicDucker(
                inner: playDispatcher,
                readMusicVolume: { [weak engine] in
                    engine?.bus(.music).outputVolume ?? 0
                },
                writeMusicVolume: { [weak engine] value in
                    engine?.setVolume(value, on: .music)
                }
            )
            dispatcher = { dispatched in ducker.dispatch(dispatched) }
        } else {
            dispatcher = playDispatcher
        }
        let coordinator = AudioCoordinator(bindings: bindings, dispatch: dispatcher) { [weak player] entity in
            player?.stopLoop(entity: entity)
        }

        let music = MusicDirector(
            section: bindings.music,
            play: { [weak player] path, fade in player?.playMusic(path, fade: fade) },
            fadeOut: { [weak player] path, fade in player?.fadeOutMusic(path, fade: fade) },
            duration: { [weak player] path in player?.duration(of: path) }
        )
        let ambientBed = AmbientBed(section: bindings.ambient) { [weak player] dispatched in
            player?.play(dispatched)
        }

        self.manifest = manifest
        self.bindings = bindings
        self.engine = engine
        self.settings = settings
        self.session = session
        self.player = player
        self.coordinator = coordinator
        self.music = music
        self.ambientBed = ambientBed
        self.ambientScene = AmbientScene(section: bindings.ambient, player: player)
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
        startClock()
    }

    /// Ticks the music and the ambient crossfades by wall-clock time,
    /// apart from the game's speed and pause.
    private func startClock() {
        clock = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.music.tick(dt: 0.1)
                self?.ambientScene?.tick(dt: 0.1)
            }
        }
    }

    /// Applies the persisted bus volumes and mute to the engine.
    private static func applyVolumes(_ settings: AudioSettings, to engine: AudioEngine) {
        engine.setVolume(settings.musicVolume, on: .music)
        engine.setVolume(settings.sfxVolume, on: .sfx)
        engine.setVolume(settings.sfxVolume, on: .ambient)
        engine.setVolume(settings.musicVolume, on: .loop)
        engine.isMuted = settings.isMuted
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
        ambientBed.consume(events: events)
        coordinator.consume(events: events)
    }

    /// Plays the interface sound bound to `ui.<name>`, if any. Spec:
    /// `audio-playback` / Interface sounds are bound by name.
    public func playInterfaceSound(_ name: String) {
        guard let cue = Self.interfaceCue(name, in: bindings) else { return }
        player.play(DispatchedCue(cue: cue))
    }

    nonisolated static func interfaceCue(_ name: String, in bindings: Bindings) -> Bindings.Cue? {
        bindings.bindings["ui.\(name)"]?.filter { $0.action == .start }.randomElement()
    }

    /// Starts a game's music: the title theme crossfades to game pieces.
    /// App shells call this when a game session starts.
    public func beginSession() {
        music.setContext(.game)
    }

    /// Ends the game session's sounds: every building loop and seasonal
    /// bed stops, and the music crossfades back to the title theme. App
    /// shells call this when the player leaves a game.
    public func endSession() {
        music.setContext(.title)
        coordinator.endSession()
        player.stopAllBuildingLoops()
        ambientScene?.endSession()
    }

    /// Forward the per-tick `WorldSnapshot` into the coordinator so it can
    /// resolve each event's primary entity to a `TileCoordinate` for the
    /// spatial layer. Call this immediately before `consume(events:)` for
    /// the same tick. Snapshots before any events are valid — the cached
    /// snapshot is just used for entity lookups.
    public func consumeSnapshot(_ snapshot: WorldSnapshot) {
        ambientScene?.consumeSnapshot(snapshot)
        music.setSeason(snapshot.date.season)
        coordinator.consumeSnapshot(snapshot)
    }

    /// Write the listener's tile-space position to the environment node.
    /// Called by the renderer at most once per second. Also re-chooses the
    /// building loops nearest the listener. The environment node is left
    /// alone if spatial audio is disabled or `tile` is nil.
    /// Per spec `audio-playback` "Listener position from camera".
    public func setListenerPosition(_ tile: TileCoordinate?) {
        player.setListener(tile)
        ambientScene?.setListener(tile)
        guard let env = engine.environmentNode, let tile else { return }
        env.listenerPosition = AVAudio3DPoint(x: Float(tile.x), y: 0, z: Float(tile.y))
    }
}
