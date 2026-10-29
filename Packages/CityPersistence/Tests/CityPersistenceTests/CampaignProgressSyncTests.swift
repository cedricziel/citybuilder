import CityCore
import Foundation
import Testing
@testable import CityPersistence

// Scenarios from openspec/changes/add-campaigns (campaigns / Campaign
// progress is a profile record).

private func ephemeralDefaults() -> UserDefaults {
    let suiteName = "CityPersistence-campaign-\(UUID().uuidString)"
    // swiftlint:disable:next force_unwrapping
    return UserDefaults(suiteName: suiteName)!
}

private func chapter(_ id: String) -> Chapter {
    Chapter(
        id: id, title: id, intro: "Intro.", ending: "Ending.", layout: .singleIsland, seed: 1, age: .medieval,
        start: ChapterStart(money: 1000, stock: [:]), goals: [GoalState(goal: .age(.renaissance))], reward: .banner(id)
    )
}

@Test("a win on one device reaches the other")
func aWinOnOneDeviceReachesTheOther() async {
    let store = InMemoryCloudKeyValueStore(available: true)
    let phone = CampaignProgressSync(store: store, defaults: ephemeralDefaults())
    let tablet = CampaignProgressSync(store: store, defaults: ephemeralDefaults())
    await phone.recordWin(of: chapter("c1"), difficulty: .normal, laurels: 0)
    await phone.recordWin(of: chapter("c2"), difficulty: .normal, laurels: 0)
    await tablet.recordWin(of: chapter("c1"), difficulty: .hard, laurels: 2)
    await phone.pullCloudToLocal()
    let merged = phone.progress
    #expect(Set(merged.won.keys) == ["c1", "c2"])
    #expect(merged.won["c1"] == ChapterRecord(difficulty: .hard, laurels: 2))
}

@Test("progress stays local without iCloud and merges once it is back")
func progressStaysLocalWithoutICloud() async {
    let store = InMemoryCloudKeyValueStore(available: false)
    let sync = CampaignProgressSync(store: store, defaults: ephemeralDefaults())
    await sync.recordWin(of: chapter("c1"), difficulty: .easy, laurels: 1)
    await sync.pullCloudToLocal()
    #expect(sync.progress.won["c1"] == ChapterRecord(difficulty: .easy, laurels: 1))
    await store.setAvailable(true)
    await store.set(Data("not json".utf8), forKey: CampaignProgressSync.key)
    await sync.pullCloudToLocal()
    #expect(sync.progress.won["c1"] == ChapterRecord(difficulty: .easy, laurels: 1))
}

@Test("scenario: deleting a save keeps progress")
func scenarioDeletingASaveKeepsProgress() async throws {
    let defaults = ephemeralDefaults()
    let sync = CampaignProgressSync(store: InMemoryCloudKeyValueStore(available: true), defaults: defaults)
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let saves = SaveStore(baseDirectory: directory)
    let gameID = UUID()
    try saves.save(World.newGame(), gameID: gameID)
    await sync.recordWin(of: chapter("c1"), difficulty: .normal, laurels: 0)
    try saves.delete(gameID: gameID)
    let reloaded = CampaignProgressSync(store: InMemoryCloudKeyValueStore(available: false), defaults: defaults)
    #expect(reloaded.progress.won["c1"] != nil)
}

@Test("an external change merges the cloud copy and reports it")
func anExternalChangeMergesTheCloudCopy() async {
    let store = InMemoryCloudKeyValueStore(available: true)
    let phone = CampaignProgressSync(store: store, defaults: ephemeralDefaults())
    let tablet = CampaignProgressSync(store: store, defaults: ephemeralDefaults())
    let center = NotificationCenter()
    let name = Notification.Name("test.campaign.change")
    let (stream, continuation) = AsyncStream.makeStream(of: CampaignProgress.self)
    let token = phone.observeExternalChanges(center: center, name: name) { continuation.yield($0) }
    await tablet.recordWin(of: chapter("c1"), difficulty: .hard, laurels: 1)
    center.post(name: name, object: nil)
    var iterator = stream.makeAsyncIterator()
    let merged = await iterator.next()
    #expect(merged?.won["c1"] == ChapterRecord(difficulty: .hard, laurels: 1))
    center.removeObserver(token)
    #expect(CampaignProgressSync.externalChangeNotification == NSUbiquitousKeyValueStore.didChangeExternallyNotification)
}

@Test("the iCloud store holds data and ignores other values")
func theICloudStoreHoldsData() async {
    let store = UbiquitousKeyValueStore(store: NSUbiquitousKeyValueStore())
    let key = "test.campaign.\(UUID().uuidString)"
    await store.set(Data("x".utf8), forKey: key)
    await store.set(3, forKey: key + ".int")
    #expect(await store.value(forKey: key + ".int") == nil)
    _ = await store.synchronize()
    #expect(await store.isAvailable())
}
