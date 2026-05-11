import Foundation
import Testing
@testable import CityAudio

// Tests for spec `audio-playback` — `Per-bus volume control` requirement,
// specifically the persistence scenarios.

private func ephemeralDefaults() -> UserDefaults {
    let suiteName = "CityAudio-test-\(UUID().uuidString)"
    // swiftlint:disable:next force_unwrapping
    return UserDefaults(suiteName: suiteName)!
}

@Test("scenario: volume settings persist")
func scenarioVolumeSettingsPersist() {
    let defaults = ephemeralDefaults()
    defer { defaults.removePersistentDomain(forName: defaults.dictionaryRepresentation().keys.first ?? "") }

    let settings1 = AudioSettings(userDefaults: defaults)
    settings1.sfxVolume = 0.3
    settings1.musicVolume = 0.4
    settings1.isMuted = true

    // A second instance reads the same backing store: persistence is local
    // to UserDefaults (relaunched apps see the same values).
    let settings2 = AudioSettings(userDefaults: defaults)
    #expect(settings2.sfxVolume == 0.3)
    #expect(settings2.musicVolume == 0.4)
    #expect(settings2.isMuted == true)
}

@Test("settings: defaults when nothing was stored")
func settingsDefaultsWhenNothingStored() {
    let defaults = ephemeralDefaults()
    let settings = AudioSettings(userDefaults: defaults)
    #expect(settings.musicVolume == AudioSettings.defaultMusicVolume)
    #expect(settings.sfxVolume == AudioSettings.defaultSFXVolume)
    #expect(settings.isMuted == false)
}
