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

// MARK: - Spatial audio settings (add-spatial-audio M5)

@Test("scenario: default settings enable spatial audio")
func scenarioDefaultSettingsEnableSpatialAudio() {
    let defaults = ephemeralDefaults()
    let settings = AudioSettings(userDefaults: defaults)
    #expect(settings.spatialAudioEnabled == true)
    #expect(settings.spatialReferenceDistance == 4.0)
    #expect(settings.spatialMaxDistance == 32.0)
}

@Test("scenario: spatial toggle persists")
func scenarioSpatialTogglePersists() {
    let defaults = ephemeralDefaults()
    let writer = AudioSettings(userDefaults: defaults)
    writer.spatialAudioEnabled = false
    writer.spatialReferenceDistance = 8.0
    writer.spatialMaxDistance = 48.0

    // A second instance reads the same backing store — survives "relaunch".
    let reader = AudioSettings(userDefaults: defaults)
    #expect(reader.spatialAudioEnabled == false)
    #expect(reader.spatialReferenceDistance == 8.0)
    #expect(reader.spatialMaxDistance == 48.0)
}

@MainActor
@Test("scenario: persisted spatial-disabled is honored by AudioStack on launch")
func scenarioPersistedSpatialDisabledIsHonoredByAudioStackOnLaunch() {
    let defaults = ephemeralDefaults()
    // Pre-stage UserDefaults to look like a prior session that turned
    // spatial off.
    defaults.set(false, forKey: AudioSettings.Key.spatialEnabled)
    let stack = AudioStack(bundle: Bundle.main, userDefaults: defaults)
    #expect(stack.settings.spatialAudioEnabled == false)
    #expect(stack.engine.isSpatialEnabled == false)
    #expect(stack.engine.environmentNode == nil)
}
