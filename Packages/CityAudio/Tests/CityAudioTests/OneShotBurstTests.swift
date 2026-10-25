import AVFoundation
import Foundation
import Testing
@testable import CityAudio

// #264: a frame that dispatches many one-shots must not restart a pool node for each of them. Each
// restart waits for the engine's next I/O cycle on the node queue, so a burst retriggers the start
// of a sample once per cycle, a rapid stutter, and keeps the queue busy for seconds.

private let burstFiles = (0 ..< 100).map { "sfx/clink-\($0).wav" }

/// One 50 ms silent file per path in `burstFiles`.
@MainActor
private let burstBundle: Bundle? = {
    var bundle: Bundle?
    for path in burstFiles {
        bundle = silentBundle(folder: "one-shot-burst-tests", file: (path as NSString).lastPathComponent, seconds: 0.05)
    }
    return bundle
}()

/// A cue player with the shipped limits, its node steps traced.
@MainActor
private final class Rig {
    let engine = AudioEngine()
    let trace = NodeTrace()
    let player: EngineCuePlayer

    init() throws {
        player = try EngineCuePlayer(engine: engine, bundle: #require(burstBundle))
        engine.nodes.trace = { [trace] in trace.record($0, $1) }
    }

    /// Dispatches one cue per path in one go, as a frame does, then waits for the node queue.
    func dispatch(_ paths: [String]) throws {
        // Held, so the queue doesn't work through cues while the frame is still dispatching them.
        let gate = engine.nodes.hold()
        for path in paths {
            player.play(DispatchedCue(cue: Bindings.Cue(file: path, bus: .sfx)))
        }
        gate.signal()
        try #require(engine.isRunning, "no audio output to test against")
        engine.nodes.settle()
    }

    var starts: Int {
        trace.steps.count(where: { $0 == .start })
    }
}

@MainActor
@Test("scenario: a burst in one frame plays once")
func burstOfIdenticalOneShotsPlaysOnce() throws {
    let rig = try Rig()
    defer { rig.engine.stop() }
    try rig.dispatch(Array(repeating: burstFiles[0], count: 100))
    #expect(rig.starts == 1)
    #expect(rig.trace.steps == [.stop, .schedule, .start])
}

@MainActor
@Test("scenario: a burst restarts each node at most once")
func burstOfDifferentOneShotsRestartsEachNodeAtMostOnce() throws {
    let rig = try Rig()
    defer { rig.engine.stop() }
    try rig.dispatch(burstFiles)
    #expect(rig.starts <= 4)
}
