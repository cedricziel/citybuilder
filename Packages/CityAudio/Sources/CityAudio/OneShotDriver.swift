import AVFoundation
import Foundation

/// Drives the one-shot pool nodes on the engine's node queue (#191). Cues reach the queue in order
/// and are handled one after another, so a cue on a running node is never heard before an earlier
/// cue whose node is still starting.
final class OneShotDriver: @unchecked Sendable {
    let nodes: AudioNodeQueue
    /// The engine run each node was started in, read and written on the node queue only. A node keeps
    /// reporting `isPlaying` after the engine stops.
    private var startedIn: [ObjectIdentifier: Int] = [:]

    init(nodes: AudioNodeQueue) {
        self.nodes = nodes
    }

    /// Plays `file` on `node`. A free node still running in this engine run only gets the file
    /// scheduled; any other node is stopped, scheduled and started, unless its engine has stopped.
    func play(_ file: AVAudioFile, on node: AVAudioPlayerNode, volume: Float?, wasFree: Bool, run: Int) {
        let file = AudioNodeQueue.Box(file)
        nodes.run(node) { node in self.perform(file.value, on: node, volume: volume, wasFree: wasFree, run: run) }
    }

    private func perform(_ file: AVAudioFile, on node: AVAudioPlayerNode, volume: Float?, wasFree: Bool, run: Int) {
        let id = ObjectIdentifier(node)
        if let volume {
            node.volume = volume
        }
        let restarts = !(wasFree && node.isPlaying && startedIn[id] == run)
        if restarts {
            node.stop()
            nodes.note(node, .stop)
        }
        node.scheduleFile(file, at: nil, completionHandler: nil)
        nodes.note(node, .schedule)
        guard restarts else { return }
        startedIn[id] = nodes.startIfRunning(node) ? run : nil
    }
}
