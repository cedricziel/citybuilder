import CityCore
import Foundation
import Testing
@testable import CityAudio

// Spec `audio-playback`: "Original music is composed and rendered in the repository".

private func shipped() throws -> (Manifest, Bindings) {
    let audio = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Resources/Audio")
    let manifest = try Manifest.load(from: Data(contentsOf: audio.appendingPathComponent("manifest.json")))
    let bindings = try Bindings.load(from: Data(contentsOf: audio.appendingPathComponent("bindings.json")), manifest: manifest)
    return (manifest, bindings)
}

@Test("scenario: music covers the menu and every season")
func musicCoversTheMenuAndEverySeason() throws {
    let music = try #require(try shipped().1.music)
    #expect(music.title != nil)
    for season in Season.allCases {
        #expect(music.tracks.contains { $0.suits(season) }, "no track suits \(season)")
    }
}

@Test("scenario: original music is credited")
func originalMusicIsCredited() throws {
    let (manifest, bindings) = try shipped()
    let music = try #require(bindings.music)
    let files = Set(music.tracks.map(\.file) + [music.title?.file].compactMap(\.self)).subtracting(["music/bards-tale.m4a"])
    #expect(files.count == 5)
    for file in files {
        let entry = try #require(manifest.entries.first { $0.path == file }, "\(file) has no manifest entry")
        #expect(entry.author == "Citybuilder original score")
        #expect(entry.license == .cc0)
        #expect(entry.title.contains("original, generated in-repo"))
    }
}
