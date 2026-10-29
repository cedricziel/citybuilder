import CityCore
import Foundation

/// Keeps campaign progress in UserDefaults, apart from world saves, and
/// merges it through the iCloud key-value store (`add-campaigns` D8).
/// Spec: `campaigns` / Campaign progress is a profile record.
public final class CampaignProgressSync: @unchecked Sendable {
    public static let key = "campaign.progress"

    private let store: CloudKeyValueStore
    private let defaults: UserDefaults

    public init(store: CloudKeyValueStore, defaults: UserDefaults = .standard) {
        self.store = store
        self.defaults = defaults
    }

    /// The local copy; empty when none was stored or it can't be read.
    public var progress: CampaignProgress {
        Self.decode(defaults.data(forKey: Self.key)) ?? CampaignProgress()
    }

    /// Records a win locally, merges the cloud copy and uploads the
    /// result. Returns true for the chapter's first win.
    @discardableResult
    public func recordWin(of chapter: Chapter, difficulty: Difficulty, laurels: Int) async -> Bool {
        var local = progress
        let first = local.recordWin(of: chapter, difficulty: difficulty, laurels: laurels)
        save(local)
        await pushLocalToCloud()
        return first
    }

    /// Merges the cloud copy into the local one, then uploads the merge.
    public func pushLocalToCloud() async {
        await pullCloudToLocal()
        if let data = Self.encode(progress) {
            await store.set(data, forKey: Self.key)
        }
        await store.synchronize()
    }

    /// Merges the cloud copy into the local one. A missing or unreadable
    /// cloud copy changes nothing.
    public func pullCloudToLocal() async {
        guard await store.isAvailable() else { return }
        let stored = await store.value(forKey: Self.key) as? Data
        guard let remote = Self.decode(stored) else { return }
        save(progress.merged(with: remote))
    }

    /// Pulls and merges whenever `center` posts `name`, which defaults to
    /// iCloud's external-change notification, then hands the merged copy
    /// to `onChange`. Keep the returned token as long as the observation
    /// should last.
    public func observeExternalChanges(
        center: NotificationCenter = .default,
        name: Notification.Name = CampaignProgressSync.externalChangeNotification,
        onChange: @escaping @Sendable (CampaignProgress) async -> Void
    ) -> any NSObjectProtocol {
        center.addObserver(forName: name, object: nil, queue: nil) { [self] _ in
            Task {
                await pullCloudToLocal()
                await onChange(progress)
            }
        }
    }

    /// iCloud's notice that the key-value store changed on another device.
    public static var externalChangeNotification: Notification.Name {
        #if canImport(Foundation) && !os(Linux)
        NSUbiquitousKeyValueStore.didChangeExternallyNotification
        #else
        Notification.Name("CampaignProgressSync.externalChange")
        #endif
    }

    private func save(_ progress: CampaignProgress) {
        defaults.set(Self.encode(progress), forKey: Self.key)
    }

    private static func encode(_ progress: CampaignProgress) -> Data? {
        try? JSONEncoder().encode(progress)
    }

    private static func decode(_ data: Data?) -> CampaignProgress? {
        data.flatMap { try? JSONDecoder().decode(CampaignProgress.self, from: $0) }
    }
}
