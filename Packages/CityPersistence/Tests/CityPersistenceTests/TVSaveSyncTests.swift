import CityCore
import Foundation
import Testing
@testable import CityPersistence

// Tests for spec `icloud-sync` — "Apple TV keeps saves in iCloud" and
// "Last-write-wins conflict policy v0", against the in-memory client.

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
    await relaunched.settle()

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
    let sync = harness.launchSync()

    let result = await sync.launch()
    await sync.settle()

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

    let resolved = await harness.launchSync().resolveConflict(gameID: id, keepICloud: true)

    #expect(resolved == .resolved)
    #expect(try harness.store.load(gameID: id) == remoteWorld)
}

@Test("Resolving a conflict for the local save replaces the iCloud copy")
func resolvingAConflictForTheLocalSaveReplacesTheICloudCopy() async throws {
    let harness = Harness()
    let id = UUID()
    try harness.store.save(world(seed: 1), gameID: id)
    _ = try await harness.client.upload(gameID: id, body: saveBytes(world(seed: 2)), deviceID: "iPad")
    try await setLocalWriteDate(harness, gameID: id, offset: -60)

    let sync = harness.launchSync()
    #expect(await sync.launch().conflicts == [id])

    let resolved = await sync.resolveConflict(gameID: id, keepICloud: false)

    #expect(resolved == .resolved)
    let uploaded = await harness.client.records[id]?.body
    #expect(try uploaded == harness.bytes(of: id))
}

@Test("scenario: stale pending upload does not overwrite a newer iCloud save")
func scenarioStalePendingUploadDoesNotOverwriteANewerICloudSave() async throws {
    let firstTV = Harness()
    let secondTV = Harness(client: firstTV.client)
    let id = UUID()
    try firstTV.store.save(world(seed: 1), gameID: id)
    try backdateLocalSave(firstTV, gameID: id)
    await firstTV.client.setAccountAvailable(false)
    await firstTV.launchSync().didSave(gameID: id)

    await firstTV.client.setAccountAvailable(true)
    try secondTV.store.save(world(seed: 2), gameID: id)
    await secondTV.launchSync().didSave(gameID: id)
    let newer = try secondTV.bytes(of: id)

    let result = await firstTV.launchSync().launch()

    #expect(await firstTV.client.records[id]?.body == newer)
    #expect(result.conflicts == [id])
}

@Test("A save written while its upload is in flight is uploaded after it")
func aSaveWrittenWhileItsUploadIsInFlightIsUploadedAfterIt() async throws {
    let harness = Harness()
    let client = HeldUploadClient(inner: harness.client)
    let sync = harness.launchSync(client: client)
    let id = UUID()
    try harness.store.save(world(seed: 1), gameID: id)
    let firstSave = Task { await sync.didSave(gameID: id) }
    await client.waitForHeldUpload()

    try harness.store.save(world(seed: 2), gameID: id)
    let secondBytes = try harness.bytes(of: id)
    let secondSave = Task { await sync.didSave(gameID: id) }
    // Give an overlapping retry the chance to upload before the first one lands.
    for _ in 0 ..< 50 where await client.uploadCalls < 2 {
        try await Task.sleep(for: .milliseconds(10))
    }
    await client.release()
    await firstSave.value
    await secondSave.value

    let remote = try #require(await harness.client.records[id])
    #expect(remote.body == secondBytes)
    #expect(await sync.pendingUploads.isEmpty)
    #expect(try abs(harness.localWriteDate(of: id).timeIntervalSince(remote.modificationDate)) < 1)
    #expect(await harness.launchSync().launch() == TVLaunchSyncResult())
}

@Test("Launch uploads a local save that never reached the pending list")
func launchUploadsALocalSaveThatNeverReachedThePendingList() async throws {
    let harness = Harness()
    let id = UUID()
    try harness.store.save(world(), gameID: id)
    let sync = harness.launchSync()

    _ = await sync.launch()
    await sync.settle()

    #expect(try await harness.client.records[id]?.body == harness.bytes(of: id))
}

@Test("Resolving a conflict for iCloud reports a failed download")
func resolvingAConflictForICloudReportsAFailedDownload() async throws {
    let harness = Harness()
    let id = UUID()
    try harness.store.save(world(seed: 1), gameID: id)
    _ = try await harness.client.upload(gameID: id, body: saveBytes(world(seed: 2)), deviceID: "iPad")
    await harness.client.setAccountAvailable(false)

    let resolved = await harness.launchSync().resolveConflict(gameID: id, keepICloud: true)

    #expect(resolved == .unreachable)
}
