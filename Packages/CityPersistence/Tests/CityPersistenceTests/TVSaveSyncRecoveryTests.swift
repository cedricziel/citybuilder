import CityCore
import Foundation
import Testing
@testable import CityPersistence

// Tests for spec `icloud-sync` — Apple TV keeps saves in iCloud: uploads
// that commit after timing out, records that change between the listing
// and the upload, and the CloudKit call time limit.

@Test("An upload that committed after timing out is not a conflict")
func anUploadThatCommittedAfterTimingOutIsNotAConflict() async throws {
    let harness = Harness()
    let client = ScriptedClient(inner: harness.client)
    await client.configure(hangsAfterUpload: true)
    let id = UUID()
    try harness.store.save(world(), gameID: id)
    // The upload lands well after the save was written.
    try backdateLocalSave(harness, gameID: id)
    await harness.launchSync(client: client, callTimeout: .milliseconds(200)).didSave(gameID: id)
    await client.release()
    #expect(await harness.client.records[id] != nil)

    let relaunched = harness.launchSync()
    let result = await relaunched.launch()
    await relaunched.settle()

    #expect(result.conflicts.isEmpty)
    #expect(await relaunched.pendingUploads.isEmpty)
    let remote = try #require(await harness.client.records[id])
    #expect(try abs(harness.localWriteDate(of: id).timeIntervalSince(remote.modificationDate)) < 1)
}

@Test("A save written while an identical iCloud copy downloads is still uploaded")
func aSaveWrittenWhileAnIdenticalICloudCopyDownloadsIsStillUploaded() async throws {
    let harness = Harness()
    let client = ScriptedClient(inner: harness.client)
    await client.configure(hangsAfterUpload: true)
    let id = UUID()
    try harness.store.save(world(seed: 1), gameID: id)
    try backdateLocalSave(harness, gameID: id)
    await harness.launchSync(client: client, callTimeout: .milliseconds(200)).didSave(gameID: id)
    await client.release()
    let store = harness.store
    await client.configure(beforeFetch: { try? store.save(world(seed: 9), gameID: id) })

    let relaunched = harness.launchSync(client: client)
    let result = await relaunched.launch()
    await relaunched.settle()

    #expect(result.conflicts.isEmpty)
    let remote = try #require(await harness.client.records[id])
    #expect(try harness.store.decode(remote.body) == world(seed: 9))
    #expect(await relaunched.pendingUploads.isEmpty)
}

@Test("A known conflict is not downloaded again on every pass")
func aKnownConflictIsNotDownloadedAgainOnEveryPass() async throws {
    let harness = Harness()
    let client = ScriptedClient(inner: harness.client)
    let id = UUID()
    try harness.store.save(world(seed: 1), gameID: id)
    try backdateLocalSave(harness, gameID: id)
    await harness.client.setAccountAvailable(false)
    await harness.launchSync().didSave(gameID: id)
    await harness.client.setAccountAvailable(true)
    _ = try await harness.client.upload(gameID: id, body: saveBytes(world(seed: 2)), deviceID: "Mac")
    let sync = harness.launchSync(client: client)
    #expect(await sync.launch().conflicts == [id])
    await sync.settle()
    let fetchesAfterLaunch = await client.fetchCalls

    await sync.retryPendingUploads()

    #expect(fetchesAfterLaunch == 1)
    #expect(await client.fetchCalls == 1)
}

@Test("An upload does not replace a record another device saved after the listing")
func anUploadDoesNotReplaceARecordAnotherDeviceSavedAfterTheListing() async throws {
    let harness = Harness()
    let client = ScriptedClient(inner: harness.client)
    let id = UUID()
    let other = try saveBytes(world(seed: 2))
    let inner = harness.client
    await client.configure(beforeUpload: { _ = try? await inner.upload(gameID: id, body: other, deviceID: "Mac") })
    try harness.store.save(world(seed: 1), gameID: id)
    try backdateLocalSave(harness, gameID: id)

    await harness.launchSync(client: client).didSave(gameID: id)

    #expect(await harness.client.records[id]?.body == other)
    #expect(await harness.launchSync().pendingUploads == [id])
}

@Test("Keeping this save is superseded by a record saved after the listing")
func keepingThisSaveIsSupersededByARecordSavedAfterTheListing() async throws {
    let harness = Harness()
    let client = ScriptedClient(inner: harness.client)
    let id = UUID()
    try harness.store.save(world(seed: 1), gameID: id)
    _ = try await harness.client.upload(gameID: id, body: saveBytes(world(seed: 2)), deviceID: "iPad")
    try await setLocalWriteDate(harness, gameID: id, offset: -60)
    let sync = harness.launchSync(client: client)
    #expect(await sync.launch().conflicts == [id])
    await sync.settle()
    let unseen = try saveBytes(world(seed: 3))
    let inner = harness.client
    await client.configure(beforeUpload: { _ = try? await inner.upload(gameID: id, body: unseen, deviceID: "Mac") })

    let resolution = await sync.resolveConflict(gameID: id, keepICloud: false)

    #expect(resolution == .superseded)
    #expect(await harness.client.records[id]?.body == unseen)
}

@Test("In-memory upload refuses a record that does not meet its expectation")
func inMemoryUploadRefusesARecordThatDoesNotMeetItsExpectation() async throws {
    let client = InMemoryCloudKitClient()
    let id = UUID()
    let first = try await client.upload(gameID: id, body: Data("a".utf8), deviceID: "iPad", expecting: .noRecord)

    await #expect(throws: SyncError.recordChanged) {
        _ = try await client.upload(gameID: id, body: Data("b".utf8), deviceID: "Mac", expecting: .noRecord)
    }
    await #expect(throws: SyncError.recordChanged) {
        _ = try await client.upload(gameID: id, body: Data("b".utf8), deviceID: "Mac", expecting: .changeTag("stale"))
    }
    let second = try await client.upload(
        gameID: id,
        body: Data("c".utf8),
        deviceID: "Mac",
        expecting: .changeTag(#require(first.changeTag))
    )
    #expect(await client.records[id] == second)
}

@Test("A timed call gives up on an operation that never returns")
func aTimedCallGivesUpOnAnOperationThatNeverReturns() async {
    let hang = Hang()

    await #expect(throws: SyncError.offline) {
        try await withTimeout(.milliseconds(100)) { await hang.wait() }
    }
    await hang.release()
}

@Test("Cancelling the caller of a timed call stops the wait")
func cancellingTheCallerOfATimedCallStopsTheWait() async {
    let hang = Hang()
    let caller = Task { () -> Bool in
        do {
            try await withTimeout(.seconds(60)) { await hang.wait() }
            return false
        } catch {
            return error is CancellationError
        }
    }

    caller.cancel()
    let cancelled = await finishing { await caller.value }

    #expect(cancelled == true)
    await hang.release()
}
