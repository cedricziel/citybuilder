import AVFoundation
import Foundation
@testable import CityAudio

/// A bundle holding `file`, `seconds` of 44.1 kHz mono silence, in a temporary folder named
/// `folder`, laid out as the cue player looks files up.
func silentBundle(folder: String, file: String, seconds: Double) -> Bundle? {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(folder)
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    let frames = AVAudioFrameCount(44100 * seconds)
    guard let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1),
          let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
          let audio = try? AVAudioFile(forWriting: url.appendingPathComponent(file), settings: format.settings)
    else { return nil }
    buffer.frameLength = frames
    try? audio.write(from: buffer)
    return Bundle(url: url)
}

/// Stops the engine behind `engine`'s back and posts the change, as the system does when the output
/// hardware changes.
@MainActor
func changeConfiguration(of engine: AudioEngine) {
    engine.underlyingEngine.stop()
    NotificationCenter.default.post(name: .AVAudioEngineConfigurationChange, object: engine.underlyingEngine)
}

/// The steps taken on player nodes, with the node and the thread each ran on.
final class NodeTrace: @unchecked Sendable {
    private let lock = NSLock()
    private struct Entry {
        let node: ObjectIdentifier
        let step: AudioNodeQueue.Step
        let onMain: Bool
    }

    private var entries: [Entry] = []

    func record(_ node: ObjectIdentifier, _ step: AudioNodeQueue.Step) {
        lock.withLock { entries.append(Entry(node: node, step: step, onMain: Thread.isMainThread)) }
    }

    var steps: [AudioNodeQueue.Step] {
        lock.withLock { entries.map(\.step) }
    }

    var nodes: [ObjectIdentifier] {
        lock.withLock { entries.map(\.node) }
    }

    var anyOnMain: Bool {
        lock.withLock { entries.contains(where: \.onMain) }
    }
}

extension AudioNodeQueue {
    /// Holds the queue until the returned gate is signalled.
    func hold() -> DispatchSemaphore {
        let gate = DispatchSemaphore(value: 0)
        queue.async { gate.wait() }
        return gate
    }

    /// Waits until the queue has handled every call so far.
    func settle() {
        queue.sync {}
    }
}
