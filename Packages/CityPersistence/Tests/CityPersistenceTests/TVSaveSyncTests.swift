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

    /// Pass `client` to put a second Apple TV on the same iCloud account.
    init(accountAvailable: Bool = true, client: InMemoryCloudKitClient? = nil) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("citybuilder-tvsync-\(UUID().uuidString)")
        store = SaveStore(baseDirectory: directory)
        self.client = client ?? InMemoryCloudKitClient(accountAvailable: accountAvailable)
    }

    /// A fresh coordinator over the same disk, cloud and defaults, as on
    /// a relaunch.
    func launchSync(client: (any CloudKitClient)? = nil) -> TVSaveSync {
        TVSaveSync(store: store, client: client ?? self.client, deviceID: "Apple TV", defaultsSuite: defaultsSuite)
    }

    func bytes(of gameID: UUID) throws -> Data {
        try store.writer.read(from: store.url(for: gameID))
    }

    func localWriteDate(of gameID: UUID) throws -> Date {
        try #require(store.writeDate(gameID: gameID))
    }
}

/// Holds the first upload until the test releases it, so a test can act
/// while that upload is in flight.
private actor HeldUploadClient: CloudKitClient {
    let inner: InMemoryCloudKitClient
    private(set) var uploadCalls = 0
    private var held: CheckedContinuation<Void, Never>?
    private var heldArrival: CheckedContinuation<Void, Never>?
    private var isHolding = true

    init(inner: InMemoryCloudKitClient) {
        self.inner = inner
    }

    func upload(gameID: UUID, body: Data, deviceID: String) async throws -> CloudRecord {
        uploadCalls += 1
        if isHolding {
            isHolding = false
            await withCheckedContinuation { continuation in
                held = continuation
                heldArrival?.resume()
                heldArrival = nil
            }
        }
        return try await inner.upload(gameID: gameID, body: body, deviceID: deviceID)
    }

    /// Returns once the first upload is being held.
    func waitForHeldUpload() async {
        guard held == nil else { return }
        await withCheckedContinuation { heldArrival = $0 }
    }

    func release() {
        held?.resume()
        held = nil
    }

    func fetchLatest(gameID: UUID) async throws -> CloudRecord? {
        try await inner.fetchLatest(gameID: gameID)
    }

    func listGames() async throws -> [CloudRecordSummary] {
        try await inner.listGames()
    }

    func isAccountAvailable() async -> Bool {
        await inner.isAccountAvailable()
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
    try await setLocalWriteDate(harness, gameID: id, offset: -60)

    let resolved = await harness.launchSync().resolveConflict(gameID: id, keepICloud: false)

    #expect(resolved)
    let uploaded = await harness.client.records[id]?.body
    #expect(try uploaded == harness.bytes(of: id))
}

@Test("scenario: stale pending upload does not overwrite a newer iCloud save")
func scenarioStalePendingUploadDoesNotOverwriteANewerICloudSave() async throws {
    let firstTV = Harness()
    let secondTV = Harness(client: firstTV.client)
    let id = UUID()
    try firstTV.store.save(world(seed: 1), gameID: id)
    try FileManager.default.setAttributes(
        [.modificationDate: Date(timeIntervalSinceNow: -60)],
        ofItemAtPath: firstTV.store.url(for: id).path
    )
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

    _ = await harness.launchSync().launch()

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

    #expect(!resolved)
}
