#if canImport(Foundation) && !os(Linux)
import Foundation

/// `NSUbiquitousKeyValueStore` as a `CloudKeyValueStore` that also holds
/// `Data`, for records such as campaign progress.
public actor UbiquitousKeyValueStore: CloudKeyValueStore {
    private let store: NSUbiquitousKeyValueStore

    public init(store: NSUbiquitousKeyValueStore = .default) {
        self.store = store
    }

    public func value(forKey key: String) -> (any Sendable)? {
        store.data(forKey: key)
    }

    public func set(_ value: any Sendable, forKey key: String) {
        if let data = value as? Data {
            store.set(data, forKey: key)
        }
    }

    @discardableResult
    public func synchronize() -> Bool {
        store.synchronize()
    }

    public func isAvailable() -> Bool {
        true
    }
}
#endif
