import AVFoundation

/// One sound on its own `AVAudioPlayerNode`, attached and routed by
/// `EngineCuePlayer`: a building loop, or a music track played once. It
/// fades in and out so starting or stopping never clicks. Its node is
/// driven on the engine's node queue (#201).
@MainActor
final class PlayerVoice: LoopVoice {
    static let loopFadeSeconds = 0.25
    /// Volume steps per second of fade: fine enough not to be heard.
    private static let stepsPerSecond = 40.0

    private let node: AVAudioPlayerNode
    private let file: AVAudioFile
    private let engine: AudioEngine
    private let volume: Float
    private let loops: Bool
    /// The node's volume as last set.
    private var level: Float = 1
    /// A voice starts once and stops once; a stopped voice's node is gone (#264).
    /// A re-schedule or fade-in from before the stop does nothing.
    private var phase = Phase.idle

    private enum Phase {
        case idle, playing, stopped
    }

    init(node: AVAudioPlayerNode, file: AVAudioFile, engine: AudioEngine, volume: Float, loops: Bool = true) {
        self.node = node
        self.file = file
        self.engine = engine
        self.volume = volume
        self.loops = loops
    }

    func start() {
        start(fade: Self.loopFadeSeconds)
    }

    func stop() {
        stop(fade: Self.loopFadeSeconds)
    }

    func start(fade: Double) {
        guard phase == .idle else { return }
        phase = .playing
        setLevel(fade > 0 ? 0 : volume)
        if loops {
            // Two copies queued, one more each time one finishes: the next
            // copy is always waiting, so there's no gap at the wrap.
            schedule()
            schedule()
        } else {
            engine.nodes.schedule(file, on: node)
        }
        engine.nodes.play(node)
        ramp(to: volume, over: fade) {}
    }

    func stop(fade: Double) {
        guard phase != .stopped else { return }
        phase = .stopped
        ramp(to: 0, over: fade) { [self] in
            engine.nodes.stopAndDetach(node, from: engine.underlyingEngine)
        }
    }

    private func setLevel(_ volume: Float) {
        level = volume
        engine.nodes.setVolume(volume, of: node)
    }

    /// Queues the file again each time it finishes playing, while this
    /// generation is current. `.dataPlayedBack` fires when the buffer has
    /// actually played, not when it was read in.
    private func schedule() {
        engine.nodes.schedule(file, on: node) { [weak self] in
            Task { @MainActor in
                guard let self, self.phase == .playing else { return }
                self.schedule()
            }
        }
    }

    private func ramp(
        to target: Float,
        over seconds: Double,
        then finish: @escaping @MainActor () -> Void
    ) {
        let start = level
        let ramping = phase
        let steps = max(1, Int((seconds * Self.stepsPerSecond).rounded()))
        let step = seconds / Double(steps)
        // The fade holds the voice: a stopped voice is already gone from its owner, and its node
        // must still fade, stop and detach.
        Task { @MainActor in
            for index in 1 ... steps {
                if step > 0 { try? await Task.sleep(for: .seconds(step)) }
                // A stop owns the volume now; a stop's own fade always finishes.
                if self.phase != ramping {
                    if target == 0 { finish() }
                    return
                }
                self.setLevel(start + (target - start) * Float(index) / Float(steps))
            }
            finish()
        }
    }
}
