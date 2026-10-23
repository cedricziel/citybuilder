import AVFoundation
import Foundation

/// Drives the one-shot pool nodes from one serial queue, so a node's calls never cross threads and
/// `AVAudioPlayerNode.play()`, which waits for the engine's next I/O cycle, never runs on the main
/// thread (#191). Cues reach the queue in order and are handled one after another, so a cue on a
/// running node is never heard before an earlier cue whose node is still starting.
final class OneShotDriver: @unchecked Sendable {
    enum Step: Equatable, Sendable {
        case stop, schedule, start, skipStart
    }

    let queue = DispatchQueue(label: "citybuilder.audio.one-shots", qos: .userInteractive)
    /// The engine run each node was started in, read and written on `queue` only. A node keeps
    /// reporting `isPlaying` after the engine stops.
    private var startedIn: [ObjectIdentifier: Int] = [:]
    /// Each step taken on a node, on `queue`, for tests.
    var trace: (@Sendable (ObjectIdentifier, Step) -> Void)?

    /// Plays `file` on `node`. A free node still running in this engine run only gets the file
    /// scheduled; any other node is stopped, scheduled and started, unless its engine has stopped.
    func play(_ file: AVAudioFile, on node: AVAudioPlayerNode, volume: Float?, wasFree: Bool, run: Int) {
        let cue = Cue(node: node, file: file)
        queue.async { self.perform(cue, volume: volume, wasFree: wasFree, run: run) }
    }

    private func perform(_ cue: Cue, volume: Float?, wasFree: Bool, run: Int) {
        let (node, id) = (cue.node, ObjectIdentifier(cue.node))
        if let volume {
            node.volume = volume
        }
        let restarts = !(wasFree && node.isPlaying && startedIn[id] == run)
        if restarts {
            node.stop()
            trace?(id, .stop)
        }
        node.scheduleFile(cue.file, at: nil, completionHandler: nil)
        trace?(id, .schedule)
        guard restarts else { return }
        guard node.engine?.isRunning == true else {
            startedIn[id] = nil
            trace?(id, .skipStart)
            return
        }
        node.play()
        startedIn[id] = run
        trace?(id, .start)
    }

    /// A node and file handed to the queue, which alone plays them.
    private struct Cue: @unchecked Sendable {
        let node: AVAudioPlayerNode
        let file: AVAudioFile
    }
}
