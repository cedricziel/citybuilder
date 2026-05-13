import Foundation
import Testing
@testable import CityPersistence

// Tests for spec `icloud-sync` — `Audio settings sync via key-value store`
// requirement.

private func ephemeralDefaults() -> UserDefaults {
    let suiteName = "CityPersistence-test-\(UUID().uuidString)"
    // swiftlint:disable:next force_unwrapping
    return UserDefaults(suiteName: suiteName)!
}

@Test("scenario: volume change uploads to kv store")
func scenarioVolumeChangeUploadsToKvStore() async {
    let defaults = ephemeralDefaults()
    let store = InMemoryCloudKeyValueStore(available: true)
    let sync = AudioSettingsSync(store: store, defaults: defaults)

    defaults.set(Float(0.4), forKey: AudioSettingsSync.Key.musicVolume)
    await sync.pushLocalToCloud()

    let uploaded = await store.value(forKey: AudioSettingsSync.Key.musicVolume) as? Float
    #expect(uploaded == 0.4)
}

@Test("scenario: other device pulls latest volume")
func scenarioOtherDevicePullsLatestVolume() async {
    let defaultsA = ephemeralDefaults()
    let defaultsB = ephemeralDefaults()
    let sharedStore = InMemoryCloudKeyValueStore(available: true)
    let syncA = AudioSettingsSync(store: sharedStore, defaults: defaultsA)
    let syncB = AudioSettingsSync(store: sharedStore, defaults: defaultsB)

    // Device A sets a volume and pushes.
    defaultsA.set(Float(0.2), forKey: AudioSettingsSync.Key.musicVolume)
    await syncA.pushLocalToCloud()

    // Device B (initially unaware) pulls.
    await syncB.pullCloudToLocal()
    let restored = defaultsB.float(forKey: AudioSettingsSync.Key.musicVolume)
    #expect(restored == 0.2)
}

@Test("scenario: spatial toggle synced to other device")
func scenarioSpatialToggleSyncedToOtherDevice() async {
    let defaultsA = ephemeralDefaults()
    let defaultsB = ephemeralDefaults()
    let sharedStore = InMemoryCloudKeyValueStore(available: true)
    let syncA = AudioSettingsSync(store: sharedStore, defaults: defaultsA)
    let syncB = AudioSettingsSync(store: sharedStore, defaults: defaultsB)

    // Device A turns spatial off and pushes.
    defaultsA.set(false, forKey: AudioSettingsSync.Key.spatialEnabled)
    defaultsA.set(Float(6.0), forKey: AudioSettingsSync.Key.spatialReferenceDistance)
    defaultsA.set(Float(40.0), forKey: AudioSettingsSync.Key.spatialMaxDistance)
    await syncA.pushLocalToCloud()

    // Device B pulls and sees the same values.
    await syncB.pullCloudToLocal()
    #expect(defaultsB.bool(forKey: AudioSettingsSync.Key.spatialEnabled) == false)
    #expect(defaultsB.float(forKey: AudioSettingsSync.Key.spatialReferenceDistance) == 6.0)
    #expect(defaultsB.float(forKey: AudioSettingsSync.Key.spatialMaxDistance) == 40.0)
}

@Test("scenario: offline volume change queued")
func scenarioOfflineVolumeChangeQueued() async {
    let defaults = ephemeralDefaults()
    let store = InMemoryCloudKeyValueStore(available: false)
    let sync = AudioSettingsSync(store: store, defaults: defaults)

    // Offline: the change is written to local UserDefaults and pushed
    // through the sync abstraction, which queues it for retry.
    defaults.set(true, forKey: AudioSettingsSync.Key.muted)
    await sync.pushLocalToCloud()

    let pending = await store.pendingKeys
    #expect(pending.contains(AudioSettingsSync.Key.muted))

    // When the device comes back online, synchronize clears the queue.
    await store.setAvailable(true)
    let synced = await store.synchronize()
    #expect(synced == true)
    let pendingAfter = await store.pendingKeys
    #expect(pendingAfter.isEmpty)
}

@Test("scenario: no icloud account does not block audio")
func scenarioNoICloudAccountDoesNotBlockAudio() async {
    // With no available cloud store, pull is a no-op — the local
    // UserDefaults values (and therefore the engine's effective volumes)
    // are unaffected by sync state.
    let defaults = ephemeralDefaults()
    defaults.set(Float(0.5), forKey: AudioSettingsSync.Key.musicVolume)
    let unavailableStore = InMemoryCloudKeyValueStore(available: false)
    let sync = AudioSettingsSync(store: unavailableStore, defaults: defaults)

    await sync.pullCloudToLocal() // no-op when cloud unavailable
    let localStill = defaults.float(forKey: AudioSettingsSync.Key.musicVolume)
    #expect(localStill == 0.5, "local volume must survive an offline pull")
}

@Test("scenario: volume change syncs to another device")
func scenarioVolumeChangeSyncsToAnotherDevice() async {
    // Restatement of `other device pulls latest volume` from the audio-
    // playback spec — same data flow, same machinery.
    let defaultsA = ephemeralDefaults()
    let defaultsB = ephemeralDefaults()
    let store = InMemoryCloudKeyValueStore(available: true)
    let syncA = AudioSettingsSync(store: store, defaults: defaultsA)
    let syncB = AudioSettingsSync(store: store, defaults: defaultsB)
    defaultsA.set(Float(0.7), forKey: AudioSettingsSync.Key.sfxVolume)
    await syncA.pushLocalToCloud()
    await syncB.pullCloudToLocal()
    #expect(defaultsB.float(forKey: AudioSettingsSync.Key.sfxVolume) == 0.7)
}

@Test("scenario: offline volume change is queued")
func scenarioOfflineVolumeChangeIsQueued() async {
    // Restatement of `offline volume change queued` from audio-playback.
    let defaults = ephemeralDefaults()
    let store = InMemoryCloudKeyValueStore(available: false)
    let sync = AudioSettingsSync(store: store, defaults: defaults)
    defaults.set(Float(0.3), forKey: AudioSettingsSync.Key.musicVolume)
    await sync.pushLocalToCloud()
    let pending = await store.pendingKeys
    #expect(pending.contains(AudioSettingsSync.Key.musicVolume))
}
