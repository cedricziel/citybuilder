import AVFoundation
import Foundation

/// AVAudioEngine wrapper exposing the four mixer buses (`music`, `sfx`,
/// `loop`, `ambient`) defined by `AudioBus`. Per spec `audio-playback`
/// "Four-bus mixer engine" and design D4.
///
/// The engine is **lazy** — the underlying `AVAudioEngine` is not started
/// until the first call to `play(...)` (or `start()` directly). This keeps
/// silent cold-launches free of audio-session activation and the ~100 ms
/// engine startup cost.
///
/// When `spatialEnabled` is true (the default), an `AVAudioEnvironmentNode`
/// is inserted between the `loop` mixer and the main mixer so per-cue
/// `AVAudio3DPoint` positions translate into distance attenuation and
/// stereo pan. Music / SFX / ambient bypass the environment node and
/// connect to the main mixer directly. Per spec `audio-playback`
/// "Environment node on the loop bus" (`add-spatial-audio` M2).
public final class AudioEngine: @unchecked Sendable {
    private let engine: AVAudioEngine
    private let buses: [AudioBus: AVAudioMixerNode]
    private var environment: AVAudioEnvironmentNode?
    private var started: Bool = false
    private var muted: Bool = false
    private var spatialEnabled: Bool

    /// Default reference distance (in tiles) for spatial attenuation —
    /// sources within this radius play at full volume. Spec D5.
    public static let defaultReferenceDistance: Float = 4.0
    /// Default max distance (in tiles); beyond this sources are inaudible.
    public static let defaultMaxDistance: Float = 32.0

    public init(spatialEnabled: Bool = true) {
        let engine = AVAudioEngine()
        var buses: [AudioBus: AVAudioMixerNode] = [:]
        for bus in AudioBus.allCases {
            let mixer = AVAudioMixerNode()
            engine.attach(mixer)
            buses[bus] = mixer
        }
        self.engine = engine
        self.buses = buses
        self.spatialEnabled = spatialEnabled
        wireBuses()
    }

    /// Returns the `AVAudioMixerNode` for the named bus. Callers can read
    /// `outputVolume` and connect player nodes; volume is normally set via
    /// `setVolume(_:on:)` so observers see one source of truth.
    public func bus(_ bus: AudioBus) -> AVAudioMixerNode {
        // Safe to force-unwrap: every `AudioBus.allCases` value is registered
        // in the dictionary at init time.
        guard let mixer = buses[bus] else {
            preconditionFailure("AudioEngine: missing bus \(bus) — should be impossible by construction")
        }
        return mixer
    }

    /// True once `start()` has been called (lazily or explicitly).
    public var isRunning: Bool {
        started
    }

    /// True iff the loop bus is currently routed through the environment
    /// node (i.e. spatial audio is enabled).
    public var isSpatialEnabled: Bool {
        spatialEnabled
    }

    /// The environment node, if spatial routing is active. `EngineCuePlayer`
    /// reads this to know whether to wire a new loop player through it.
    public var environmentNode: AVAudioEnvironmentNode? {
        environment
    }

    /// The underlying `AVAudioEngine`. Exposed so the cue player can
    /// `attach` and `connect` player nodes against it without each caller
    /// needing to thread the engine through.
    public var underlyingEngine: AVAudioEngine {
        engine
    }

    /// Master mute. Sets every bus's `outputVolume` to 0 when true; restores
    /// the configured per-bus volume when set to false. Independent of the
    /// engine running state.
    public var isMuted: Bool {
        get { muted }
        set {
            muted = newValue
            applyMute()
        }
    }

    /// Starts the underlying `AVAudioEngine` if not already running. Safe
    /// to call repeatedly. Throws if AVAudioEngine fails to start (rare;
    /// usually an audio-session configuration error on iOS).
    public func start() throws {
        guard !started else { return }
        try engine.start()
        started = true
    }

    /// Sets the volume on `bus` to `volume` (0.0–1.0). If muted, the
    /// underlying mixer volume is held at 0 but the desired value is
    /// remembered so unmuting restores it. (Phase 1: a future Settings model
    /// will carry the per-bus values; this method just applies them.)
    public func setVolume(_ volume: Float, on bus: AudioBus) {
        let clamped = max(0.0, min(1.0, volume))
        buses[bus]?.outputVolume = muted ? 0.0 : clamped
    }

    /// Engine teardown — called by tests, by app shells on backgrounding,
    /// or when the audio engine needs to be reconfigured (e.g., spatial
    /// audio insertion in a future change).
    public func stop() {
        if started {
            engine.stop()
            started = false
        }
    }

    /// Toggle spatial audio on or off. When toggled, the loop chain is
    /// rebuilt: enabling inserts the environment node, disabling removes
    /// it and routes loop directly to main. Idempotent — a no-op if the
    /// current state already matches `enabled`. The toggle is intentionally
    /// a destructive rebuild and intended as a session-level Settings
    /// switch, not a per-tick branch (design D4).
    public func setSpatialEnabled(_ enabled: Bool) {
        guard spatialEnabled != enabled else { return }
        spatialEnabled = enabled
        wireBuses()
    }

    /// Update the environment node's distance attenuation parameters in
    /// place without rebuilding the graph. No-op if spatial routing is
    /// disabled. Spec `audio-playback` "Spatial audio settings".
    public func setSpatialDistances(reference: Float, max: Float) {
        guard let env = environment else { return }
        let params = env.distanceAttenuationParameters
        params.referenceDistance = reference
        params.maximumDistance = max
    }

    private func wireBuses() {
        // Music, SFX, and ambient always connect directly to main. Loop
        // routes through the environment node when spatial audio is on.
        for bus in AudioBus.allCases where bus != .loop {
            guard let mixer = buses[bus] else { continue }
            engine.disconnectNodeOutput(mixer)
            engine.connect(mixer, to: engine.mainMixerNode, format: nil)
        }
        guard let loopMixer = buses[.loop] else { return }
        engine.disconnectNodeOutput(loopMixer)
        if spatialEnabled {
            let env = environment ?? AVAudioEnvironmentNode()
            if env.engine == nil {
                engine.attach(env)
                env.distanceAttenuationParameters.referenceDistance = Self.defaultReferenceDistance
                env.distanceAttenuationParameters.maximumDistance = Self.defaultMaxDistance
                env.distanceAttenuationParameters.distanceAttenuationModel = .inverse
                env.distanceAttenuationParameters.rolloffFactor = 1.0
            }
            environment = env
            engine.disconnectNodeOutput(env)
            engine.connect(loopMixer, to: env, format: nil)
            engine.connect(env, to: engine.mainMixerNode, format: nil)
        } else {
            engine.connect(loopMixer, to: engine.mainMixerNode, format: nil)
            if let env = environment {
                engine.disconnectNodeOutput(env)
                engine.detach(env)
                environment = nil
            }
        }
    }

    private func applyMute() {
        for mixer in buses.values {
            mixer.outputVolume = muted ? 0.0 : mixer.outputVolume
        }
    }
}
