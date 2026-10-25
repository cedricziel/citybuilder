import AVFoundation
import Foundation
import Testing
@testable import CityAudio

// Spec `audio-playback`: "One-shots play in one format". A pool node is connected for one format,
// and AVFAudio traps on a buffer of another; the shipped one-shots mix mono 44.1 kHz with stereo
// 48 kHz (`ui/place-thunk.caf`).

private let audioDir = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("Resources/Audio")

private func shippedBindings() throws -> Bindings {
    let manifest = try Manifest.load(from: Data(contentsOf: audioDir.appendingPathComponent("manifest.json")))
    return try Bindings.load(from: Data(contentsOf: audioDir.appendingPathComponent("bindings.json")), manifest: manifest)
}

@Test("scenario: every shipped one-shot loads in the pool's format")
func everyShippedOneShotLoadsInThePoolFormat() throws {
    let files = try Set(shippedBindings().bindings.values.joined()
        .filter { $0.action == .start && $0.loop != true }
        .map(\.file))
    #expect(!files.isEmpty)
    for file in files.sorted() {
        let buffer = OneShotBuffer.load(audioDir.appendingPathComponent(file))
        #expect(buffer?.format == OneShotBuffer.format, "\(file) doesn't load as a one-shot")
        #expect((buffer?.frameLength ?? 0) > 0, "\(file) is empty")
    }
}

@Test("a mono one-shot plays from both sides")
func monoOneShotPlaysFromBothSides() throws {
    let buffer = try #require(OneShotBuffer.load(audioDir.appendingPathComponent("ui/tap.caf")))
    let channels = try #require(buffer.floatChannelData)
    let frames = Int(buffer.frameLength)
    let left = UnsafeBufferPointer(start: channels[0], count: frames)
    let right = UnsafeBufferPointer(start: channels[1], count: frames)
    #expect(left.contains { $0 != 0 })
    #expect(Array(left) == Array(right))
}

@MainActor
@Test("scenario: one-shots of different formats share a node")
func oneShotsOfDifferentFormatsShareANode() throws {
    let engine = AudioEngine()
    defer { engine.stop() }
    let trace = NodeTrace()
    let player = try EngineCuePlayer(engine: engine, bundle: #require(Bundle(url: audioDir)), oneShotPoolSize: 1)
    engine.nodes.trace = { trace.record($0, $1) }
    player.play(DispatchedCue(cue: Bindings.Cue(file: "ui/tap.caf", bus: .sfx)))
    try #require(engine.isRunning, "no audio output to test against")
    engine.nodes.settle()
    // Mono 44.1 kHz, then stereo 48 kHz on the same, running node.
    player.play(DispatchedCue(cue: Bindings.Cue(file: "ui/place-thunk.caf", bus: .sfx)))
    engine.nodes.settle()
    #expect(trace.steps == [.stop, .schedule, .start, .schedule])
}
