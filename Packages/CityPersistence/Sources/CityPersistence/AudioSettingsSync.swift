import Foundation

/// Abstraction over the platform's iCloud key-value store so unit tests use
/// a fast in-memory fake while production talks to `NSUbiquitousKeyValueStore`.
/// Per spec `icloud-sync` "Audio settings sync via key-value store".
public protocol CloudKeyValueStore: Sendable {
    func value(forKey key: String) async -> (any Sendable)?
    func set(_ value: any Sendable, forKey key: String) async
    /// Forces a synchronize attempt. Returns true if the local cache was
    /// successfully reconciled with the remote store; false if offline.
    @discardableResult
    func synchronize() async -> Bool
    /// Whether the user is signed into iCloud. The local fallback path
    /// kicks in when this is false.
    func isAvailable() async -> Bool
}

/// In-memory test double. Tracks every set and exposes the latest value
/// per key. `synchronize()` returns `available`; toggle `available` on
/// the actor to simulate offline / no-iCloud.
public actor InMemoryCloudKeyValueStore: CloudKeyValueStore {
    public var storage: [String: any Sendable] = [:]
    public var available: Bool

    /// Set of keys written since the last synchronize attempt — analog of
    /// the OS-level queue that NSUbiquitousKeyValueStore maintains while
    /// offline. Surfaced for tests asserting the "offline change queued"
    /// scenario.
    public private(set) var pendingKeys: Set<String> = []

    public init(available: Bool = true) {
        self.available = available
    }

    public func value(forKey key: String) async -> (any Sendable)? {
        storage[key]
    }

    public func set(_ value: any Sendable, forKey key: String) async {
        storage[key] = value
        if !available {
            pendingKeys.insert(key)
        }
    }

    public func synchronize() async -> Bool {
        guard available else { return false }
        pendingKeys.removeAll()
        return true
    }

    public func isAvailable() async -> Bool {
        available
    }

    public func setAvailable(_ value: Bool) {
        available = value
    }
}

/// Mirrors the three audio settings keys (`audio.musicVolume`,
/// `audio.sfxVolume`, `audio.muted`) between local UserDefaults and the
/// iCloud key-value store. Per spec `icloud-sync`.
///
/// Not an actor — `UserDefaults` is not `Sendable` under strict concurrency
/// but is thread-safe at the OS level. We wrap it as `@unchecked Sendable`
/// and serialize all access through the async push/pull methods.
public final class AudioSettingsSync: @unchecked Sendable {
    public enum Key {
        public static let musicVolume = "audio.musicVolume"
        public static let sfxVolume = "audio.sfxVolume"
        public static let muted = "audio.muted"
        public static let spatialEnabled = "audio.spatialEnabled"
        public static let spatialReferenceDistance = "audio.spatialReferenceDistance"
        public static let spatialMaxDistance = "audio.spatialMaxDistance"
        public static let all = [
            musicVolume,
            sfxVolume,
            muted,
            spatialEnabled,
            spatialReferenceDistance,
            spatialMaxDistance
        ]
    }

    private let store: CloudKeyValueStore
    private let defaults: UserDefaults

    public init(store: CloudKeyValueStore, defaults: UserDefaults = .standard) {
        self.store = store
        self.defaults = defaults
    }

    /// Push every local audio setting to the cloud store. Called whenever
    /// the user changes a slider or toggles mute.
    public func pushLocalToCloud() async {
        for key in Key.all {
            // UserDefaults stores `Any?`; project values into the small
            // set of `Sendable` types the cloud store accepts.
            if let value = sendableValue(forKey: key) {
                await store.set(value, forKey: key)
            }
        }
        await store.synchronize()
    }

    /// Pull the latest values from the cloud store into UserDefaults.
    /// Called on app launch and when the OS posts a cloud-changed
    /// notification.
    public func pullCloudToLocal() async {
        guard await store.isAvailable() else { return }
        for key in Key.all {
            if let value = await store.value(forKey: key) {
                defaults.set(value, forKey: key)
            }
        }
    }

    /// Coerces a `UserDefaults` value to a `Sendable` view appropriate to
    /// the audio settings keys. Anything outside the expected Bool/Number
    /// range is treated as absent.
    private func sendableValue(forKey key: String) -> (any Sendable)? {
        guard let raw = defaults.object(forKey: key) else { return nil }
        if let boolValue = raw as? Bool { return boolValue }
        if let floatValue = raw as? Float { return floatValue }
        if let doubleValue = raw as? Double { return doubleValue }
        if let intValue = raw as? Int { return intValue }
        return nil
    }
}
