import AVFoundation
import Foundation
import Testing

private let audioDir = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("Resources/Audio")

@Test("scenario: generated sounds open on apple platforms")
func generatedSoundsOpenOnApplePlatforms() throws {
    let files = try #require(FileManager.default.enumerator(at: audioDir, includingPropertiesForKeys: nil))
        .compactMap { $0 as? URL }
        .filter { $0.pathExtension == "caf" }
    #expect(!files.isEmpty)
    for url in files {
        let file = try AVAudioFile(forReading: url)
        #expect(file.length > 0, "\(url.lastPathComponent) has no frames")
    }
}
