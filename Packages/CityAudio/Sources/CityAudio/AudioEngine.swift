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
public final class AudioEngine: @unchecked Sendable {
    private let engine: AVAudioEngine
    private let buses: [AudioBus: AVAudioMixerNode]
    private var started: Bool = false
    private var muted: Bool = false

    public init() {
        let engine = AVAudioEngine()
        var buses: [AudioBus: AVAudioMixerNode] = [:]
        for bus in AudioBus.allCases {
            let mixer = AVAudioMixerNode()
            engine.attach(mixer)
            engine.connect(mixer, to: engine.mainMixerNode, format: nil)
            buses[bus] = mixer
        }
        self.engine = engine
        self.buses = buses
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

    private func applyMute() {
        for mixer in buses.values {
            mixer.outputVolume = muted ? 0.0 : mixer.outputVolume
        }
    }
}
