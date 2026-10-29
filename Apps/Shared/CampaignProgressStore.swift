import CityPersistence
import CityUI
import Foundation

/// Campaign progress backed by UserDefaults and the iCloud key-value store,
/// merged whenever another device changes it. Spec: `campaigns` / Campaign
/// progress is a profile record.
@MainActor
enum CampaignProgressStore {
    private static var observer: (any NSObjectProtocol)?

    static func make() -> CampaignProgressModel {
        let sync = CampaignProgressSync(store: UbiquitousKeyValueStore())
        // The stored copy arrives a moment later, merged with iCloud's.
        let model = CampaignProgressModel { chapter, difficulty, laurels in
            await sync.recordWin(of: chapter, difficulty: difficulty, laurels: laurels)
        }
        observer = sync.observeExternalChanges { progress in
            await MainActor.run { model.merge(progress) }
        }
        Task {
            await sync.pullCloudToLocal()
            let progress = await sync.progress
            model.merge(progress)
        }
        return model
    }
}
