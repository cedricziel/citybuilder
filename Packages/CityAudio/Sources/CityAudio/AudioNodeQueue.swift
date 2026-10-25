import AVFoundation
import Foundation
import os

/// The one serial queue every call on the engine's player nodes runs on: one-shots, loops and music
/// alike. A node is then driven from one thread, `AVAudioPlayerNode.play()`, which waits for the
/// engine's next I/O cycle, never runs on the main thread, and a node's calls run in the order they
/// were made, so a queued `play()` never comes after the node's detach (#191, #201).
final class AudioNodeQueue: @unchecked Sendable {
    enum Step: Equatable, Sendable {
        case stop, schedule, start, skipStart, volume, detach, drop
    }

    let queue = DispatchQueue(label: "citybuilder.audio.nodes", qos: .userInteractive)
    /// Each step taken on a node, on `queue`, for tests.
    var trace: (@Sendable (ObjectIdentifier, Step) -> Void)?
    private let currentRun = OSAllocatedUnfairLock<Int?>(initialState: nil)

    /// The engine's run while it runs, nil while it is stopped. Set on the engine's thread, read on
    /// the queue, so a call queued under one run can tell the engine has stopped or started again.
    var liveRun: Int? {
        get { currentRun.withLock { $0 } }
        set { currentRun.withLock { $0 = newValue } }
    }

    func note(_ node: AVAudioNode, _ step: Step) {
        trace?(ObjectIdentifier(node), step)
    }

    /// Runs `body` with `node` on the queue.
    func run(_ node: AVAudioPlayerNode, _ body: @escaping @Sendable (AVAudioPlayerNode) -> Void) {
        let box = Box(node)
        queue.async { body(box.value) }
    }

    /// Starts `node`, unless its engine has stopped.
    func play(_ node: AVAudioPlayerNode) {
        run(node) { [self] node in startIfRunning(node) }
    }

    /// Starts `node` now, on the queue, unless its engine has stopped; whether it started.
    @discardableResult
    func startIfRunning(_ node: AVAudioPlayerNode) -> Bool {
        guard node.engine?.isRunning == true else {
            note(node, .skipStart)
            return false
        }
        node.play()
        note(node, .start)
        return true
    }

    func setVolume(_ volume: Float, of node: AVAudioPlayerNode) {
        run(node) { [self] node in
            node.volume = volume
            note(node, .volume)
        }
    }

    /// Queues `file` on `node`; `finished` runs once it has played back.
    func schedule(_ file: AVAudioFile, on node: AVAudioPlayerNode, finished: (@Sendable () -> Void)? = nil) {
        let file = Box(file)
        run(node) { [self] node in
            node.scheduleFile(file.value, at: nil, completionCallbackType: .dataPlayedBack) { _ in finished?() }
            note(node, .schedule)
        }
    }

    /// Stops `node` and detaches it from `engine`, after every call queued before.
    func stopAndDetach(_ node: AVAudioPlayerNode, from engine: AVAudioEngine) {
        let engine = Box(engine)
        run(node) { [self] node in
            node.stop()
            note(node, .stop)
            guard node.engine === engine.value else { return }
            engine.value.detach(node)
            note(node, .detach)
        }
    }

    /// A value handed to the queue, which alone uses it from then on.
    struct Box<Value>: @unchecked Sendable {
        let value: Value

        init(_ value: Value) {
            self.value = value
        }
    }
}
