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
    /// One-shots handed to the queue that it hasn't handled yet.
    private let waiting = OSAllocatedUnfairLock(initialState: 0)
    /// A one-shot is dropped while this many wait: a start can take an I/O cycle, so a longer
    /// line would play late and stutter (#264). Spec: `audio-playback` / One-shot starts never back up.
    static let maxWaiting = 4

    init(nodes: AudioNodeQueue) {
        self.nodes = nodes
    }

    /// True while the queue has as many one-shots waiting as it may.
    var isBackedUp: Bool {
        waiting.withLock { $0 >= Self.maxWaiting }
    }

    /// Plays `buffer` on `node`. A node running in this engine run gets the buffer scheduled, after
    /// its last cue if that has ended, cutting it off if not; only a node not running is stopped,
    /// scheduled and started, unless its engine has stopped. A cue whose run has ended by its turn
    /// is dropped.
    func play(_ buffer: AVAudioPCMBuffer, on node: AVAudioPlayerNode, volume: Float?, wasFree: Bool, run: Int) {
        let buffer = AudioNodeQueue.Box(buffer)
        waiting.withLock { $0 += 1 }
        nodes.run(node) { node in
            defer { self.waiting.withLock { $0 -= 1 } }
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
