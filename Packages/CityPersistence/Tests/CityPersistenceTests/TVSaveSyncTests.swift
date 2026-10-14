import CityCore
import Foundation
import Testing
@testable import CityPersistence

// Tests for spec `icloud-sync` — "Apple TV keeps saves in iCloud" and
// "Last-write-wins conflict policy v0", against the in-memory client.

private struct Harness {
    let store: SaveStore
    let client: InMemoryCloudKitClient
    let defaultsSuite = "citybuilder-tvsync-\(UUID().uuidString)"

    init(accountAvailable: Bool = true) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("citybuilder-tvsync-\(UUID().uuidString)")
        store = SaveStore(baseDirectory: directory)
        client = InMemoryCloudKitClient(accountAvailable: accountAvailable)
    }

    /// A fresh coordinator over the same disk, cloud and defaults, as on
    /// a relaunch.
    func launchSync() -> TVSaveSync {
        TVSaveSync(store: store, client: client, deviceID: "Apple TV", defaultsSuite: defaultsSuite)
    }
}

private func world(seed: UInt64 = 1) -> World {
    World.fixtureWithTerrain(width: 4, height: 4, fill: .grass, seed: seed)
}

private func saveBytes(_ world: World) throws -> Data {
    let scratch = SaveStore(baseDirectory: FileManager.default.temporaryDirectory
        .appendingPathComponent("citybuilder-tvsync-scratch-\(UUID().uuidString)"))
    let id = UUID()
    try scratch.save(world, gameID: id)
    return try scratch.writer.read(from: scratch.url(for: id))
}

/// Dates the local save of `gameID` `offset` seconds from its remote record.
private func setLocalWriteDate(_ harness: Harness, gameID: UUID, offset: TimeInterval) async throws {
    let remote = try #require(await harness.client.records[gameID]).modificationDate
    try FileManager.default.setAttributes(
        [.modificationDate: remote.addingTimeInterval(offset)],
        ofItemAtPath: harness.store.url(for: gameID).path
    )
}

@Test("scenario: autosave on Apple TV is uploaded")
func scenarioAutosaveOnAppleTVIsUploaded() async throws {
    let harness = Harness()
    let sync = harness.launchSync()
    let id = UUID()
    try harness.store.save(world(), gameID: id)

    await sync.didSave(gameID: id)

    let uploaded = await harness.client.records[id]?.body
    #expect(try uploaded == harness.store.writer.read(from: harness.store.url(for: id)))
    #expect(await sync.pendingUploads.isEmpty)
}

@Test("scenario: failed upload is retried at launch")
func scenarioFailedUploadIsRetriedAtLaunch() async throws {
    let harness = Harness(accountAvailable: false)
    let id = UUID()
    try harness.store.save(world(), gameID: id)
    await harness.launchSync().didSave(gameID: id)
    #expect(await harness.client.records[id] == nil)

    await harness.client.setAccountAvailable(true)
    let relaunched = harness.launchSync()
    #expect(await relaunched.pendingUploads == [id])
    _ = await relaunched.launch()

    #expect(await harness.client.records[id] != nil)
    #expect(await relaunched.pendingUploads.isEmpty)
}

@Test("Failed upload is retried at the next save")
func failedUploadIsRetriedAtTheNextSave() async throws {
    let harness = Harness(accountAvailable: false)
    let sync = harness.launchSync()
    let first = UUID()
    let second = UUID()
    try harness.store.save(world(), gameID: first)
    await sync.didSave(gameID: first)

    await harness.client.setAccountAvailable(true)
    try harness.store.save(world(seed: 2), gameID: second)
    await sync.didSave(gameID: second)

    #expect(await harness.client.records[first] != nil)
    #expect(await harness.client.records[second] != nil)
}

@Test("scenario: launch restores saves missing from caches")
func scenarioLaunchRestoresSavesMissingFromCaches() async throws {
    let harness = Harness()
    let id = UUID()
    let remoteWorld = world(seed: 7)
    _ = try await harness.client.upload(gameID: id, body: saveBytes(remoteWorld), deviceID: "iPad")

    let result = await harness.launchSync().launch()

    #expect(result.restored == [id])
    #expect(try harness.store.listSaves().map(\.gameID) == [id])
    #expect(try harness.store.load(gameID: id) == remoteWorld)
}

@Test("scenario: missing local copy downloads without a prompt")
func scenarioMissingLocalCopyDownloadsWithoutAPrompt() async throws {
    let harness = Harness()
    let id = UUID()
    _ = try await harness.client.upload(gameID: id, body: saveBytes(world()), deviceID: "Mac")

    let result = await harness.launchSync().launch()

    #expect(result.restored == [id])
    #expect(result.conflicts.isEmpty)
}

@Test("Launch keeps a local save that is older than its remote and reports the conflict")
func launchKeepsAnOlderLocalSaveAndReportsTheConflict() async throws {
    let harness = Harness()
    let id = UUID()
    try harness.store.save(world(seed: 1), gameID: id)
    let localBytes = try harness.store.writer.read(from: harness.store.url(for: id))
    _ = try await harness.client.upload(gameID: id, body: saveBytes(world(seed: 2)), deviceID: "iPad")
    try await setLocalWriteDate(harness, gameID: id, offset: -60)

    let result = await harness.launchSync().launch()

    #expect(result.conflicts == [id])
    #expect(result.restored.isEmpty)
    #expect(try harness.store.writer.read(from: harness.store.url(for: id)) == localBytes)
}

@Test("Launch uploads a local save that is newer than its remote")
func launchUploadsANewerLocalSave() async throws {
    let harness = Harness()
    let id = UUID()
    _ = try await harness.client.upload(gameID: id, body: saveBytes(world(seed: 2)), deviceID: "iPad")
    try harness.store.save(world(seed: 1), gameID: id)
    try await setLocalWriteDate(harness, gameID: id, offset: 60)

    let result = await harness.launchSync().launch()

    #expect(result.conflicts.isEmpty)
    let uploaded = await harness.client.records[id]?.body
    #expect(try uploaded == harness.store.writer.read(from: harness.store.url(for: id)))
}

@Test("A synced save is not a conflict at the next launch")
func aSyncedSaveIsNotAConflictAtTheNextLaunch() async throws {
    let harness = Harness()
    let id = UUID()
    try harness.store.save(world(), gameID: id)
    await harness.launchSync().didSave(gameID: id)

    let result = await harness.launchSync().launch()

    #expect(result == TVLaunchSyncResult())
}

@Test("Launch skips a remote save that does not decode")
func launchSkipsACorruptRemoteSave() async throws {
    let harness = Harness()
    let id = UUID()
    _ = try await harness.client.upload(gameID: id, body: Data("not a save".utf8), deviceID: "iPad")

    let result = await harness.launchSync().launch()

    #expect(result.restored.isEmpty)
    #expect(!harness.store.exists(gameID: id))
}

@Test("Resolving a conflict for iCloud replaces the local save")
func resolvingAConflictForICloudReplacesTheLocalSave() async throws {
    let harness = Harness()
    let id = UUID()
    let remoteWorld = world(seed: 2)
    try harness.store.save(world(seed: 1), gameID: id)
    _ = try await harness.client.upload(gameID: id, body: saveBytes(remoteWorld), deviceID: "iPad")

    await harness.launchSync().resolveConflict(gameID: id, keepICloud: true)

    #expect(try harness.store.load(gameID: id) == remoteWorld)
}

@Test("Resolving a conflict for the local save replaces the iCloud copy")
func resolvingAConflictForTheLocalSaveReplacesTheICloudCopy() async throws {
    let harness = Harness()
    let id = UUID()
    try harness.store.save(world(seed: 1), gameID: id)
    _ = try await harness.client.upload(gameID: id, body: saveBytes(world(seed: 2)), deviceID: "iPad")

    await harness.launchSync().resolveConflict(gameID: id, keepICloud: false)

    let uploaded = await harness.client.records[id]?.body
    #expect(try uploaded == harness.store.writer.read(from: harness.store.url(for: id)))
}
