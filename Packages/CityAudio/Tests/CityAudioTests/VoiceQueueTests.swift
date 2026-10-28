import AVFoundation
import Foundation
import Testing
@testable import CityAudio

// #201: music and loop voices start, fade, stop and detach on the engine's node queue, in order,
// so a queued `play()` never runs after the node's detach, and fades still reach their volume.

/// One second of silence as `music/tune.wav`.
@MainActor
private let tuneBundle = silentBundle(folder: "voice-queue-tests", file: "tune.wav", seconds: 1)

private let tune = "music/tune.wav"

@MainActor
private final class Rig {
    let engine = AudioEngine()
    let trace = NodeTrace()
    let player: EngineCuePlayer

    init() throws {
        player = try EngineCuePlayer(engine: engine, bundle: #require(tuneBundle))
        engine.nodes.trace = { [trace] in trace.record($0, $1) }
    }

    /// The music voice's node: the only player attached, as no one-shot has played.
    var musicNode: AVAudioPlayerNode? {
        engine.underlyingEngine.attachedNodes.lazy.compactMap { $0 as? AVAudioPlayerNode }.first
    }

    /// Lets fades on the main actor run, then waits for the node queue.
    func settle(_ seconds: Double) async throws {
        try await Task.sleep(for: .seconds(seconds))
        engine.nodes.queue.sync {}
    }

    /// Settles until `done` holds, for up to two seconds: other tests can hold the main actor.
    func settle(until done: () -> Bool) async throws {
        for _ in 0 ..< 40 where !done() {
            try await settle(0.05)
        }
    }

    func volume(of node: AVAudioPlayerNode) -> Float {
        let node = AudioNodeQueue.Box(node)
        return engine.nodes.queue.sync { node.value.volume }
    }
}

@MainActor
@Test("a voice stopped right after it starts is detached after its start, off the main thread")
func voiceStoppedRightAfterStartDetachesLast() async throws {
    let rig = try Rig()
    defer { rig.engine.stop() }
    try #require(rig.player.playMusic(tune, fade: 0), "no audio output to test against")
    let node = try #require(rig.musicNode)
    rig.player.fadeOutMusic(tune, fade: 0)
    try await rig.settle { node.engine == nil }
    let steps = rig.trace.steps
    let start = try #require(steps.firstIndex(of: .start))
    let detach = try #require(steps.firstIndex(of: .detach))
    #expect(start < detach)
    #expect(steps.last == .detach)
    #expect(node.engine == nil)
    #expect(!rig.trace.anyOnMain)
}

@MainActor
@Test("a stop while the start waits on the queue still detaches after it")
func stopWhileTheStartWaitsDetachesAfterIt() async throws {
    let rig = try Rig()
    defer { rig.engine.stop() }
    rig.engine.nodes.queue.async { Thread.sleep(forTimeInterval: 0.1) }
    try #require(rig.player.playMusic(tune, fade: 0), "no audio output to test against")
    rig.player.fadeOutMusic(tune, fade: 0)
    try await rig.settle { rig.trace.steps.contains(.detach) }
    let steps = rig.trace.steps
    #expect(steps.firstIndex(of: .start) ?? .max < steps.firstIndex(of: .detach) ?? -1)
    #expect(steps.last == .detach)
}

@MainActor
@Test("a fade in still reaches the voice's volume, step by step")
func fadeInReachesTheVoiceVolume() async throws {
    let rig = try Rig()
    defer { rig.engine.stop() }
    try #require(rig.player.playMusic(tune, fade: 0.1), "no audio output to test against")
    let node = try #require(rig.musicNode)
    try await rig.settle { abs(rig.volume(of: node) - 1) < 0.001 }
    #expect(abs(rig.volume(of: node) - 1) < 0.001)
    #expect(rig.trace.steps.count(where: { $0 == .volume }) >= 4)
}

/// Before #201 the fade held its voice weakly; a voice its owner had let go never finished fading,
/// and the track went on playing at full volume.
@MainActor
@Test("a fade out lowers a released voice to silence, then detaches it")
func fadeOutFinishesForAReleasedVoice() async throws {
    let rig = try Rig()
    defer { rig.engine.stop() }
    try #require(rig.player.playMusic(tune, fade: 0.05, loops: true), "no audio output to test against")
    let node = try #require(rig.musicNode)
    try await rig.settle(0.15)
    rig.player.fadeOutMusic(tune, fade: 0.1)
    try await rig.settle { node.engine == nil }
    #expect(node.engine == nil)
    #expect(rig.trace.steps.suffix(2) == [.stop, .detach])
}

/// A looping voice on its own node, attached to the music bus, not started.
@MainActor
private func loopingVoice(_ rig: Rig) throws -> (PlayerVoice, AVAudioPlayerNode) {
    let file = try AVAudioFile(forReading: #require(tuneBundle?.url(forResource: "tune", withExtension: "wav")))
    let node = AVAudioPlayerNode()
    rig.engine.underlyingEngine.attach(node)
    rig.engine.underlyingEngine.connect(node, to: rig.engine.bus(.music), format: file.processingFormat)
    try rig.engine.start()
    return (PlayerVoice(node: node, file: file, engine: rig.engine, volume: 1), node)
}

@MainActor
@Test("scenario: a second start does nothing")
func secondVoiceStartDoesNothing() async throws {
    let rig = try Rig()
    defer { rig.engine.stop() }
    let (voice, _) = try loopingVoice(rig)
    voice.start(fade: 0)
    voice.start(fade: 0)
    try await rig.settle(0.05)
    #expect(rig.trace.steps.count(where: { $0 == .schedule }) == 2)
    #expect(rig.trace.steps.count(where: { $0 == .start }) == 1)
}

@MainActor
@Test("scenario: a second stop does nothing")
func secondVoiceStopDoesNothing() async throws {
    let rig = try Rig()
    defer { rig.engine.stop() }
    let (voice, node) = try loopingVoice(rig)
    voice.start(fade: 0)
    voice.stop(fade: 0)
    voice.stop(fade: 0)
    voice.start(fade: 0)
    try await rig.settle { node.engine == nil }
    try await rig.settle(0.05)
    #expect(rig.trace.steps.count(where: { $0 == .stop }) == 1)
    #expect(rig.trace.steps.count(where: { $0 == .detach }) == 1)
    #expect(rig.trace.steps.last == .detach)
}
