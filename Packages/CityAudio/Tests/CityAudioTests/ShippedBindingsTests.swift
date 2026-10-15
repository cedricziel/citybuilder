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

@Test("scenario: a broken bindings file is reported")
func brokenBindingsFileIsReported() throws {
    let bundleURL = FileManager.default.temporaryDirectory.appendingPathComponent("broken-\(UUID().uuidString).bundle")
    try FileManager.default.createDirectory(at: bundleURL, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: bundleURL) }
    try Data(#"{"version":1,"bindings":{"gameOver":[{"file":"x.caf"}]}}"#.utf8)
        .write(to: bundleURL.appendingPathComponent("bindings.json"))
    let bundle = try #require(Bundle(url: bundleURL))
    var reports: [String] = []
    let bindings = AudioBundleLoader.loadBindings(manifest: Manifest(), in: bundle) { reports.append($0) }
    #expect(bindings == Bindings())
    #expect(reports.count == 1)
    #expect(reports.first?.contains("bindings.json") == true)
}
