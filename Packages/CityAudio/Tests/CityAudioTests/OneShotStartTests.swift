import AVFoundation
import Foundation
import Testing
@testable import CityAudio

// #191: one-shot pool nodes are driven from one serial queue, never from the calling thread, which
// is the main thread during `GameSession.step`.

/// One 50 ms silent `blip.wav`.
@MainActor
private let blipBundle = silentBundle(folder: "one-shot-start-tests", file: "blip.wav", seconds: 0.05)

private let blip = DispatchedCue(cue: Bindings.Cue(file: "sfx/blip.wav", bus: .sfx))

/// The steps the driver took, with the thread each ran on.
private final class Trace: @unchecked Sendable {
    private let lock = NSLock()
    private struct Entry {
        let node: ObjectIdentifier
        let step: OneShotDriver.Step
        let onMain: Bool
    }

    private var entries: [Entry] = []

    func record(_ node: ObjectIdentifier, _ step: OneShotDriver.Step) {
        lock.withLock { entries.append(Entry(node: node, step: step, onMain: Thread.isMainThread)) }
    }

    var steps: [OneShotDriver.Step] {
        lock.withLock { entries.map(\.step) }
    }

    var nodes: [ObjectIdentifier] {
        lock.withLock { entries.map(\.node) }
    }

    var anyOnMain: Bool {
        lock.withLock { entries.contains(where: \.onMain) }
    }
}

/// A cue player whose driver steps are traced.
@MainActor
private final class Rig {
    let engine = AudioEngine()
    let trace = Trace()
    let player: EngineCuePlayer

    init(poolSize: Int) throws {
        player = try EngineCuePlayer(engine: engine, bundle: #require(blipBundle), oneShotPoolSize: poolSize)
        player.oneShots.trace = { [trace] in trace.record($0, $1) }
    }

    /// Plays `count` blips back to back, after checking the engine came up.
    func play(_ count: Int) throws {
        for _ in 0 ..< count {
            player.play(blip)
            try #require(engine.isRunning, "no audio output to test against")
        }
    }

    /// Waits until the driver has handled every cue so far.
    func settle() {
        player.oneShots.queue.sync {}
    }

    /// Holds the driver's queue for `seconds`, as a slow start would.
    func stall(_ seconds: Double) {
        player.oneShots.queue.async { Thread.sleep(forTimeInterval: seconds) }
    }
}

@MainActor
@Test("one-shot nodes are driven off the calling thread")
func oneShotNodesAreDrivenOffTheCallingThread() throws {
    let rig = try Rig(poolSize: 2)
    defer { rig.engine.stop() }
    try rig.play(2)
    rig.settle()
    #expect(rig.trace.steps == [.stop, .schedule, .start, .stop, .schedule, .start])
    #expect(!rig.trace.anyOnMain)
}

@MainActor
@Test("a free running node only schedules the next one-shot")
func freeRunningNodeOnlySchedulesTheNextOneShot() throws {
    let rig = try Rig(poolSize: 4)
    defer { rig.engine.stop() }
    try rig.play(4)
    rig.settle()
    Thread.sleep(forTimeInterval: 0.08)
    try rig.play(4)
    rig.settle()
    #expect(rig.trace.steps.suffix(4) == Array(repeating: .schedule, count: 4))
}

@MainActor
@Test("a cue on a running node waits for an earlier cue's start")
func cueOnARunningNodeWaitsForAnEarlierStart() throws {
    let rig = try Rig(poolSize: 2)
    defer { rig.engine.stop() }
    try rig.play(1)
    rig.settle()
    Thread.sleep(forTimeInterval: 0.08)
    // The next cue goes to the second node, which has never started; the one after to the first,
    // which runs and is free again. Its schedule must wait for the second node's start.
    rig.stall(0.05)
    try rig.play(2)
    rig.settle()
    let first = rig.trace.nodes[0]
    #expect(rig.trace.steps.suffix(4) == [.stop, .schedule, .start, .schedule])
    #expect(rig.trace.nodes.suffix(4) == [rig.trace.nodes[3], rig.trace.nodes[3], rig.trace.nodes[3], first])
}

@MainActor
@Test("a cue behind a queued start on the same node doesn't drop it")
func cueBehindAQueuedStartKeepsIt() throws {
    let rig = try Rig(poolSize: 1)
    defer { rig.engine.stop() }
    rig.stall(0.15)
    try rig.play(1)
    Thread.sleep(forTimeInterval: 0.08)
    try rig.play(1)
    rig.settle()
    #expect(rig.trace.steps == [.stop, .schedule, .start, .schedule])
}

@MainActor
@Test("an engine stop while a start waits skips it, and the node starts again later")
func engineStopWhileAStartWaits() throws {
    let rig = try Rig(poolSize: 1)
    defer { rig.engine.stop() }
    rig.stall(0.05)
    try rig.play(1)
    rig.engine.stop()
    rig.settle()
    #expect(rig.trace.steps == [.stop, .schedule, .skipStart])
    try rig.play(1)
    rig.settle()
    #expect(rig.trace.steps.suffix(3) == [.stop, .schedule, .start])
    #expect(rig.player.oneShotNodes(on: .sfx).first?.isPlaying == true)
}

@MainActor
@Test("after a configuration change the next one-shot starts its node again")
func configurationChangeRestartsPoolNodes() throws {
    let rig = try Rig(poolSize: 1)
    defer { rig.engine.stop() }
    try rig.play(1)
    rig.settle()
    Thread.sleep(forTimeInterval: 0.08)
    changeConfiguration(of: rig.engine)
    try rig.play(1)
    rig.settle()
    #expect(rig.trace.steps.suffix(3) == [.stop, .schedule, .start])
}
