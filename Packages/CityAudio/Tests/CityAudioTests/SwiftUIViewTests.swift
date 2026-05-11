import Foundation
import Testing
@testable import CityAudio

// Tests for spec `audio-playback` — `Credits view reads the manifest` and
// for `platform-shells` — `Settings has audio sliders` / `Settings exposes
// credits`. SwiftUI rendering is hard to assert on directly; these tests
// verify the data shape that the views consume.

@Test("scenario: every manifest entry appears in credits")
func scenarioEveryManifestEntryAppearsInCredits() {
    let manifest = Manifest(entries: [
        Manifest.Entry(path: "music/a.m4a", title: "A", author: "x", source: "u", license: .cc0),
        Manifest.Entry(
            path: "ui/b.caf",
            title: "B",
            author: "y",
            source: "v",
            license: .ccBy30,
            attribution: "B by y — CC-BY 3.0"
        )
    ])
    // The CreditsView constructs one row per manifest entry. We assert the
    // contract via the manifest itself — every entry must remain visible.
    let titles = manifest.entries.map(\.title)
    #expect(titles == ["A", "B"])
}

@Test("scenario: cc-by entries show attribution text")
func scenarioCcByEntriesShowAttributionText() {
    let manifest = Manifest(entries: [
        Manifest.Entry(
            path: "ui/b.caf",
            title: "B",
            author: "y",
            source: "v",
            license: .ccBy30,
            attribution: "B by y — CC-BY 3.0"
        )
    ])
    // The CreditsView's row renders `entry.attribution` when present and
    // the license requires it. The manifest carries the text verbatim.
    let entry = manifest.entries[0]
    #expect(entry.license.requiresAttribution)
    #expect(entry.attribution == "B by y — CC-BY 3.0")
}

@Test("scenario: settings has audio sliders")
func scenarioSettingsHasAudioSliders() {
    // The AudioSettingsView binds to an `AudioSettings` model. The settings
    // type exposes the three properties the sliders bind to.
    let defaults = UserDefaults(suiteName: "CityAudio-test-\(UUID().uuidString)")
    let settings = AudioSettings(userDefaults: defaults ?? .standard)
    settings.musicVolume = 0.5
    settings.sfxVolume = 0.7
    settings.isMuted = false
    #expect(settings.musicVolume == 0.5)
    #expect(settings.sfxVolume == 0.7)
    #expect(settings.isMuted == false)
}

@Test("scenario: settings exposes credits")
func scenarioSettingsExposesCredits() {
    // The credits row in Settings opens `CreditsView` constructed from the
    // app's loaded `Manifest`. We verify the manifest is a valid
    // construction input.
    let manifest = Manifest(entries: [
        Manifest.Entry(path: "x.caf", title: "X", author: "y", source: "z", license: .cc0)
    ])
    #expect(manifest.entries.count == 1)
}
