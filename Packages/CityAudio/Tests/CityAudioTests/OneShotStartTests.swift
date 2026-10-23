import AVFoundation
import Foundation
import Testing
@testable import CityAudio

// #191: one-shots never call `AVAudioPlayerNode.play()` on the calling thread, which is the main
// thread during `GameSession.step`.

/// A bundle holding one 50 ms silent `blip.wav`, laid out as the cue player looks files up.
private let blipBundle: Bundle? = {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("one-shot-start-tests")
    try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    guard let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1),
          let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 2205),
          let file = try? AVAudioFile(forWriting: folder.appendingPathComponent("blip.wav"), settings: format.settings)
    else { return nil }
    buffer.frameLength = 2205
    try? file.write(from: buffer)
    return Bundle(url: folder)
}()

private let blip = DispatchedCue(cue: Bindings.Cue(file: "sfx/blip.wav", bus: .sfx))

/// A cue player whose node starts are counted, and run on the calling thread unless `starts` is false.
@MainActor
private final class Rig {
    let engine = AudioEngine()
    var starts = 0
    private(set) var player: EngineCuePlayer!

    init(poolSize: Int, starts startsNodes: Bool = true) throws {
        player = try EngineCuePlayer(engine: engine, bundle: #require(blipBundle), oneShotPoolSize: poolSize) { [unowned self] node in
            starts += 1
            if startsNodes { node.play() }
        }
    }

    /// Plays `count` blips back to back, after checking the engine came up.
    func play(_ count: Int) throws {
        for _ in 0 ..< count {
            player.play(blip)
            try #require(engine.isRunning, "no audio output to test against")
        }
    }
}

@MainActor
@Test("a one-shot never starts its node on the calling thread")
func oneShotNeverStartsItsNodeOnTheCallingThread() throws {
    let rig = try Rig(poolSize: 2, starts: false)
    defer { rig.engine.stop() }
    try rig.play(1)
    #expect(rig.starts == 1)
    #expect(rig.player.oneShotNodes(on: .sfx).allSatisfy { !$0.isPlaying }, "play() ran on the calling thread")
}

@MainActor
@Test("a free running node only schedules the next one-shot")
func freeRunningNodeOnlySchedulesTheNextOneShot() throws {
    let rig = try Rig(poolSize: 4)
    defer { rig.engine.stop() }
    try rig.play(4)
    #expect(rig.starts == 4, "each pool node starts once")
    Thread.sleep(forTimeInterval: 0.08)
    try rig.play(4)
    #expect(rig.starts == 4, "cues on free running nodes start nothing")
}

@MainActor
@Test("a node stopped with the engine starts again")
func nodeStoppedWithTheEngineStartsAgain() throws {
    let rig = try Rig(poolSize: 1)
    defer { rig.engine.stop() }
    try rig.play(1)
    Thread.sleep(forTimeInterval: 0.08)
    rig.engine.stop()
    try rig.play(1)
    #expect(rig.starts == 2)
}

@Test("the default start runs off the main thread")
func defaultStartRunsOffTheMainThread() async throws {
    let engine = AVAudioEngine()
    let node = AVAudioPlayerNode()
    engine.attach(node)
    engine.connect(node, to: engine.mainMixerNode, format: nil)
    try engine.start()
    defer { engine.stop() }
    await MainActor.run { EngineCuePlayer.startOffMain(node) }
    for _ in 0 ..< 100 where !node.isPlaying {
        try await Task.sleep(for: .milliseconds(10))
    }
    #expect(node.isPlaying)
}
