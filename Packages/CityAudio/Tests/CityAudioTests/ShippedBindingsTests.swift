import Foundation
import Testing
@testable import CityAudio

// Spec `audio-playback`: "Stop cues need no bus" and "A broken audio
// document is reported".

private let audioDir = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("Resources/Audio")

@Test("scenario: shipped bindings decode with bus-less stop cues")
func shippedBindingsDecode() throws {
    let manifest = try Manifest.load(from: Data(contentsOf: audioDir.appendingPathComponent("manifest.json")))
    let bindings = try Bindings.load(from: Data(contentsOf: audioDir.appendingPathComponent("bindings.json")), manifest: manifest)
    let stops = try #require(bindings.bindings["productionStalled"])
    #expect(!stops.isEmpty)
    #expect(stops.allSatisfy { $0.action == .stop })
}

@Test("scenario: a start cue without a bus is rejected")
func startCueWithoutBusIsRejected() {
    let json = Data(#"{"version":1,"bindings":{"gameOver":[{"file":"x.caf"}]}}"#.utf8)
    #expect(throws: DecodingError.self) { try JSONDecoder().decode(Bindings.self, from: json) }
}
