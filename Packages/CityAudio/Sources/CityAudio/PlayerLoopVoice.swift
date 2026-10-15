import AVFoundation

/// A building loop on its own `AVAudioPlayerNode`, attached and routed by
/// `EngineCuePlayer`. It fades in and out over `fadeSeconds` so a loop
/// that starts or stops as the camera moves doesn't click.
@MainActor
final class PlayerLoopVoice: LoopVoice {
    static let fadeSeconds = 0.25
    private static let fadeSteps = 10

    private let node: AVAudioPlayerNode
    private let file: AVAudioFile
    private let engine: AVAudioEngine
    private let volume: Float
    /// Bumped on every start and stop; a re-schedule from an older
    /// generation is stale and does nothing.
    private var generation = 0

    init(node: AVAudioPlayerNode, file: AVAudioFile, engine: AVAudioEngine, volume: Float) {
        self.node = node
        self.file = file
        self.engine = engine
        self.volume = volume
    }

    func start() {
        generation += 1
        node.volume = 0
        // Two copies queued, one more each time one finishes: the next
        // copy is always waiting, so there's no gap at the wrap.
        schedule(generation: generation)
        schedule(generation: generation)
        node.play()
        ramp(to: volume, generation: generation) {}
    }

    func stop() {
        generation += 1
        let node = node
        let engine = engine
        ramp(to: 0, generation: generation) {
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

    private func ramp(to target: Float, generation ramping: Int, then finish: @escaping @MainActor () -> Void) {
        let start = node.volume
        let step = Self.fadeSeconds / Double(Self.fadeSteps)
        Task { @MainActor [weak self] in
            for index in 1 ... Self.fadeSteps {
                try? await Task.sleep(for: .seconds(step))
                guard let self else { return }
                // A newer start or stop owns the volume now; a stop still finishes.
                if self.generation != ramping {
                    if target == 0 { finish() }
                    return
                }
                self.node.volume = start + (target - start) * Float(index) / Float(Self.fadeSteps)
            }
            finish()
        }
    }
}
