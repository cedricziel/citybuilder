import Foundation
import Testing
@testable import CityAudio

// Spec `audio-playback`: "Interface sounds are bound by name".

@Test("scenario: interface sounds are bound")
func interfaceSoundsAreBound() throws {
    let audio = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Resources/Audio")
    let manifest = try Manifest.load(from: Data(contentsOf: audio.appendingPathComponent("manifest.json")))
    let bindings = try Bindings.load(from: Data(contentsOf: audio.appendingPathComponent("bindings.json")), manifest: manifest)
    let generated = Set(manifest.entries.filter { $0.author == "Citybuilder sound generator" }.map(\.path))
    for name in ["tap", "select", "toggle", "open", "close", "reject"] {
        let cue = try #require(AudioStack.interfaceCue(name, in: bindings), "ui.\(name) is unbound")
        #expect(cue.bus == .sfx)
        #expect(generated.contains(cue.file))
    }
}

@Test("scenario: interface sound lookup")
func interfaceSoundLookup() {
    let bindings = Bindings(bindings: ["ui.open": [Bindings.Cue(file: "ui/open.caf", bus: .sfx)]])
    #expect(AudioStack.interfaceCue("open", in: bindings)?.file == "ui/open.caf")
    #expect(AudioStack.interfaceCue("missing", in: bindings) == nil)
}
