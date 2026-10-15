import AVFoundation

/// One sound on its own `AVAudioPlayerNode`, attached and routed by
/// `EngineCuePlayer`: a building loop, or a music track played once. It
/// fades in and out so starting or stopping never clicks.
@MainActor
final class PlayerVoice: LoopVoice {
    static let loopFadeSeconds = 0.25
    /// Volume steps per second of fade: fine enough not to be heard.
    private static let stepsPerSecond = 40.0

    private let node: AVAudioPlayerNode
    private let file: AVAudioFile
    private let engine: AVAudioEngine
    private let volume: Float
    private let loops: Bool
    /// Bumped on every start and stop; a re-schedule from an older
    /// generation is stale and does nothing.
    private var generation = 0

    init(node: AVAudioPlayerNode, file: AVAudioFile, engine: AVAudioEngine, volume: Float, loops: Bool = true) {
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
        node.volume = fade > 0 ? 0 : volume
        if loops {
            // Two copies queued, one more each time one finishes: the next
            // copy is always waiting, so there's no gap at the wrap.
            schedule(generation: generation)
            schedule(generation: generation)
        } else {
            node.scheduleFile(file, at: nil, completionHandler: nil)
        }
        node.play()
        ramp(to: volume, over: fade, generation: generation) {}
    }

    func stop(fade: Double) {
        generation += 1
        let node = node
        let engine = engine
        ramp(to: 0, over: fade, generation: generation) {
            node.stop()
            engine.detach(node)
        }
    }

    /// Queues the file again each time it finishes playing, while this
    /// generation is current. `.dataPlayedBack` fires when the buffer has
    /// actually played, not when it was read in.
    private func schedule(generation scheduled: Int) {
        node.scheduleFile(file, at: nil, completionCallbackType: .dataPlayedBack) { [weak self] _ in
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
        let start = node.volume
        let steps = max(1, Int((seconds * Self.stepsPerSecond).rounded()))
        let step = seconds / Double(steps)
        Task { @MainActor [weak self] in
            for index in 1 ... steps {
                if step > 0 { try? await Task.sleep(for: .seconds(step)) }
                guard let self else { return }
                // A newer start or stop owns the volume now; a stop still finishes.
                if self.generation != ramping {
                    if target == 0 { finish() }
                    return
                }
                self.node.volume = start + (target - start) * Float(index) / Float(steps)
            }
            finish()
        }
    }
}
