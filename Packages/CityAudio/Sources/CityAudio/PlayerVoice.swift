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
    /// Bumped on every start and stop; a re-schedule from an older
    /// generation is stale and does nothing.
    private var generation = 0

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
        generation += 1
        setLevel(fade > 0 ? 0 : volume)
        if loops {
            // Two copies queued, one more each time one finishes: the next
            // copy is always waiting, so there's no gap at the wrap.
            schedule(generation: generation)
            schedule(generation: generation)
        } else {
            engine.nodes.schedule(file, on: node)
        }
        engine.nodes.play(node)
        ramp(to: volume, over: fade, generation: generation) {}
    }

    func stop(fade: Double) {
        generation += 1
        ramp(to: 0, over: fade, generation: generation) { [self] in
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
    private func schedule(generation scheduled: Int) {
        engine.nodes.schedule(file, on: node) { [weak self] in
            Task { @MainActor in
                guard let self, self.generation == scheduled else { return }
                self.schedule(generation: scheduled)
            }
        }
    }

    private func ramp(
        to target: Float,
        over seconds: Double,
        generation ramping: Int,
        then finish: @escaping @MainActor () -> Void
    ) {
        let start = level
        let steps = max(1, Int((seconds * Self.stepsPerSecond).rounded()))
        let step = seconds / Double(steps)
        // The fade holds the voice: a stopped voice is already gone from its owner, and its node
        // must still fade, stop and detach.
        Task { @MainActor in
            for index in 1 ... steps {
                if step > 0 { try? await Task.sleep(for: .seconds(step)) }
                // A newer start or stop owns the volume now; a stop still finishes.
                if self.generation != ramping {
                    if target == 0 { finish() }
                    return
                }
                self.setLevel(start + (target - start) * Float(index) / Float(steps))
            }
            finish()
        }
    }
}
