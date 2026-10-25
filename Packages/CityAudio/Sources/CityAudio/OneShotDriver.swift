import AVFoundation
import Foundation
import os

/// Drives the one-shot pool nodes on the engine's node queue (#191). Cues reach the queue in order
/// and are handled one after another, so a cue on a running node is never heard before an earlier
/// cue whose node is still starting.
final class OneShotDriver: @unchecked Sendable {
    let nodes: AudioNodeQueue
    /// The engine run each node was started in, read and written on the node queue only. A node keeps
    /// reporting `isPlaying` after the engine stops.
    private var startedIn: [ObjectIdentifier: Int] = [:]
    /// The keys of one-shots handed to the queue that it hasn't handled yet.
    private let waiting = OSAllocatedUnfairLock(initialState: Set<String>())

    init(nodes: AudioNodeQueue) {
        self.nodes = nodes
    }

    /// True while a one-shot keyed `key` still waits on the queue. Another would play late, after
    /// it, as a stutter while the queue is held up (#264). Spec: `audio-playback` / One-shot starts
    /// never back up.
    func isWaiting(_ key: String) -> Bool {
        waiting.withLock { $0.contains(key) }
    }

    /// Plays `buffer` on `node`. A node running in this engine run gets the buffer scheduled, after
    /// its last cue if that has ended, cutting it off if not; only a node not running is stopped,
    /// scheduled and started, unless its engine has stopped. A cue whose engine run has ended by its
    /// turn is dropped; so is one played while the engine is stopped.
    func play(_ buffer: AVAudioPCMBuffer, key: String, on node: AVAudioPlayerNode, volume: Float?, wasFree: Bool) {
        guard let run = nodes.liveRun else { return }
        let buffer = AudioNodeQueue.Box(buffer)
        waiting.withLock { _ = $0.insert(key) }
        nodes.run(node) { node in
            defer { self.waiting.withLock { _ = $0.remove(key) } }
            guard self.nodes.liveRun == run else {
                self.nodes.note(node, .drop)
                return
            }
            self.perform(buffer.value, on: node, volume: volume, wasFree: wasFree, run: run)
        }
    }

    /// Stopping and starting a busy node instead would wait an I/O cycle per cue, and a burst would
    /// retrigger one sample every cycle (#264).
    private func perform(
        _ buffer: AVAudioPCMBuffer, on node: AVAudioPlayerNode, volume: Float?, wasFree: Bool, run: Int
    ) {
        let id = ObjectIdentifier(node)
        if let volume {
            node.volume = volume
        }
        let running = node.isPlaying && startedIn[id] == run
        if !running {
            node.stop()
            nodes.note(node, .stop)
        }
        node.scheduleBuffer(buffer, at: nil, options: running && !wasFree ? .interrupts : [])
        nodes.note(node, .schedule)
        guard !running else { return }
        startedIn[id] = nodes.startIfRunning(node) ? run : nil
    }
}
