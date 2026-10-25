import AVFoundation
import Foundation
import Testing
@testable import CityAudio

// #206: when the output hardware changes, the system stops the engine and posts
// `AVAudioEngineConfigurationChange`. `AudioEngine` starts it again as a new run.

/// An engine with a player on the music bus, playing two seconds of silence.
@MainActor
private func playingEngine() throws -> (AudioEngine, AVAudioPlayerNode) {
    let engine = AudioEngine()
    let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1))
    let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 88200))
    buffer.frameLength = 88200
    let node = AVAudioPlayerNode()
    engine.underlyingEngine.attach(node)
    engine.underlyingEngine.connect(node, to: engine.bus(.music), format: format)
    try engine.start()
    node.scheduleBuffer(buffer, at: nil)
    node.play()
    return (engine, node)
}

/// How far `node` has played, in samples, or nil while its timing is unavailable.
private func position(of node: AVAudioPlayerNode) -> AVAudioFramePosition? {
    node.lastRenderTime.flatMap(node.playerTime(forNodeTime:))?.sampleTime
}

/// Polls `node` until `isDone` holds for its position or two seconds pass, and returns the last position.
private func waitForPosition(
    of node: AVAudioPlayerNode, until isDone: (AVAudioFramePosition) -> Bool
) -> AVAudioFramePosition? {
    let deadline = Date().addingTimeInterval(2)
    var current = position(of: node)
    while current.map(isDone) != true, Date() < deadline {
        Thread.sleep(forTimeInterval: 0.01)
        current = position(of: node)
    }
    return current
}

@MainActor
@Test("a configuration change starts the engine again as a new run")
func configurationChangeStartsTheEngineAgain() throws {
    let (engine, _) = try playingEngine()
    defer { engine.stop() }
    let run = engine.runCount
    changeConfiguration(of: engine)
    #expect(engine.underlyingEngine.isRunning)
    #expect(engine.isRunning)
    #expect(engine.runCount == run + 1)
}

@MainActor
@Test("a player keeps its place across a configuration change")
func playerKeepsItsPlaceAcrossAConfigurationChange() throws {
    let (engine, node) = try playingEngine()
    defer { engine.stop() }
    let before = try #require(waitForPosition(of: node) { $0 > 0 })
    changeConfiguration(of: engine)
    // The restarted engine renders its first cycle some time later; on a slow
    // runner that can exceed any fixed sleep, so wait for the first position it
    // renders. A reset shows here as a first new position below `before`.
    let first = try #require(waitForPosition(of: node) { $0 != before })
    #expect(first >= before)
    let later = try #require(waitForPosition(of: node) { $0 > first })
    #expect(node.isPlaying)
    #expect(before > 0)
    #expect(later > first)
}

@MainActor
@Test("a configuration change leaves an engine the game stopped alone")
func configurationChangeLeavesAStoppedEngineAlone() throws {
    let (engine, _) = try playingEngine()
    engine.stop()
    let run = engine.runCount
    changeConfiguration(of: engine)
    #expect(!engine.underlyingEngine.isRunning)
    #expect(engine.runCount == run)
}
