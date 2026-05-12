#if canImport(Foundation) && !os(Linux)
import CityPersistence
import Foundation

/// Production-side wrapper around `NSUbiquitousKeyValueStore` conforming to
/// `CloudKeyValueStore` (from CityPersistence). App shells inject one of
/// these into `AudioSettingsSync` for cross-device volume sync. Headless /
/// test contexts inject `InMemoryCloudKeyValueStore` instead.
///
/// Lives in `CityAudio` (not CityPersistence) so the iCloud-specific
/// Sendable casts stay scoped to the audio package — `CityPersistence`'s
/// abstraction stays clean and headless-friendly.
public actor UbiquitousAudioSettingsStore: CloudKeyValueStore {
    private let store: NSUbiquitousKeyValueStore

    public init(store: NSUbiquitousKeyValueStore = .default) {
        self.store = store
    }

    public func value(forKey key: String) -> (any Sendable)? {
        // Project the underlying value through the small set of Sendable
        // types the audio settings actually use. Anything else is treated
        // as absent — defensive against future schema additions.
        let raw: Any? = store.object(forKey: key)
        guard let raw else { return nil }
        if let boolValue = raw as? Bool { return boolValue }
        if let floatValue = raw as? Float { return floatValue }
        if let doubleValue = raw as? Double { return doubleValue }
        if let intValue = raw as? Int { return intValue }
        return nil
    }

    public func set(_ value: any Sendable, forKey key: String) {
        if let boolValue = value as? Bool {
            store.set(boolValue, forKey: key)
        } else if let intValue = value as? Int {
            store.set(Int64(intValue), forKey: key)
        } else if let doubleValue = value as? Double {
            store.set(doubleValue, forKey: key)
        } else if let floatValue = value as? Float {
            store.set(Double(floatValue), forKey: key)
        }
    }

    @discardableResult
    public func synchronize() -> Bool {
        store.synchronize()
    }

    public func isAvailable() -> Bool {
        // NSUbiquitousKeyValueStore does not expose an explicit "signed in"
        // check; if `default` is non-nil the iCloud entitlement is present
        // and the platform will sync when an account is available.
        true
    }
}
#endif
