import CityCore
import Foundation
import Testing
@testable import CityPersistence

// Tests for spec `icloud-sync` — Apple TV keeps saves in iCloud: time
// limits, overlapping passes and conflicts that change while the player
// decides.

@Test("scenario: unanswered iCloud call does not hold the title screen")
func scenarioUnansweredICloudCallDoesNotHoldTheTitleScreen() async {
    let harness = Harness()
    let client = ScriptedClient(inner: harness.client)
    await client.configure(hangsListing: true)
    let sync = harness.launchSync(client: client, callTimeout: .milliseconds(200))

    let result = await finishing(within: .seconds(3)) { await sync.launch() }

    #expect(result == TVLaunchSyncResult())
    await client.release()
}

@Test("Launch returns before its uploads finish")
func launchReturnsBeforeItsUploadsFinish() async throws {
    let harness = Harness()
    let client = ScriptedClient(inner: harness.client)
    let id = UUID()
    try harness.store.save(world(), gameID: id)
    await client.configure(hangsUploads: true)
    let sync = harness.launchSync(client: client)

    let result = await finishing(within: .seconds(3)) { await sync.launch() }
    await client.release()

    #expect(result == TVLaunchSyncResult())
    await sync.settle()
    #expect(try await harness.client.records[id]?.body == harness.bytes(of: id))
}

@Test("A retry when the app becomes active does not hold up launch")
func aRetryWhenTheAppBecomesActiveDoesNotHoldUpLaunch() async throws {
    let harness = Harness()
    let client = ScriptedClient(inner: harness.client)
    let pending = UUID()
    try harness.store.save(world(), gameID: pending)
    await harness.client.setAccountAvailable(false)
    await harness.launchSync().didSave(gameID: pending)
    await harness.client.setAccountAvailable(true)
    let restored = UUID()
    _ = try await harness.client.upload(gameID: restored, body: saveBytes(world(seed: 3)), deviceID: "iPad")
    await client.configure(hangsUploads: true)
    let sync = harness.launchSync(client: client)

    let retry = Task { await sync.retryPendingUploads() }
    let result = await finishing(within: .seconds(3)) { await sync.launch() }
    await client.release()
    await retry.value

    #expect(result?.restored == [restored])
}

@Test("Launch does not overwrite a save written while it downloads")
func launchDoesNotOverwriteASaveWrittenWhileItDownloads() async throws {
    let harness = Harness()
    let client = ScriptedClient(inner: harness.client)
    let id = UUID()
    _ = try await harness.client.upload(gameID: id, body: saveBytes(world(seed: 2)), deviceID: "iPad")
    let store = harness.store
    await client.configure(beforeFetch: { try? store.save(world(seed: 1), gameID: id) })

    let result = await harness.launchSync(client: client).launch()

    #expect(result.restored.isEmpty)
    #expect(try harness.store.load(gameID: id) == world(seed: 1))
}

@Test("scenario: keeping the local save after a newer iCloud save arrived asks again")
func scenarioKeepingTheLocalSaveAfterANewerICloudSaveArrivedAsksAgain() async throws {
    let harness = Harness()
    let id = UUID()
    try harness.store.save(world(seed: 1), gameID: id)
    _ = try await harness.client.upload(gameID: id, body: saveBytes(world(seed: 2)), deviceID: "iPad")
    try await setLocalWriteDate(harness, gameID: id, offset: -60)
    let sync = harness.launchSync()
    #expect(await sync.launch().conflicts == [id])
    let unseen = try saveBytes(world(seed: 3))
    _ = try await harness.client.upload(gameID: id, body: unseen, deviceID: "Mac")

    let first = await sync.resolveConflict(gameID: id, keepICloud: false)

    #expect(first == .superseded)
    #expect(await harness.client.records[id]?.body == unseen)

    let second = await sync.resolveConflict(gameID: id, keepICloud: false)

    #expect(second == .resolved)
    #expect(try await harness.client.records[id]?.body == harness.bytes(of: id))
}

@Test("Another Apple TV's upload right after this one's sync is not taken for it")
func anotherAppleTVsUploadRightAfterThisOnesSyncIsNotTakenForIt() async throws {
    let harness = Harness()
    let sync = harness.launchSync()
    let id = UUID()
    try harness.store.save(world(seed: 1), gameID: id)
    await sync.didSave(gameID: id)
    let otherTV = try saveBytes(world(seed: 2))
    _ = try await harness.client.upload(gameID: id, body: otherTV, deviceID: "Apple TV")
    try harness.store.save(world(seed: 3), gameID: id)
    try await setLocalWriteDate(harness, gameID: id, offset: -60)

    await sync.didSave(gameID: id)

    #expect(await harness.client.records[id]?.body == otherTV)
    #expect(await sync.launch().conflicts == [id])
}

@Test("Launch and a save running at once both settle")
func launchAndASaveRunningAtOnceBothSettle() async throws {
    let harness = Harness()
    let saved = UUID()
    let remoteOnly = UUID()
    try harness.store.save(world(seed: 1), gameID: saved)
    _ = try await harness.client.upload(gameID: remoteOnly, body: saveBytes(world(seed: 2)), deviceID: "iPad")
    let sync = harness.launchSync()

    async let launched = sync.launch()
    async let didSave: Void = sync.didSave(gameID: saved)
    let result = await launched
    await didSave
    await sync.settle()

    #expect(result.restored == [remoteOnly])
    #expect(result.conflicts.isEmpty)
    #expect(try await harness.client.records[saved]?.body == harness.bytes(of: saved))
    #expect(await sync.pendingUploads.isEmpty)
    #expect(await harness.launchSync().launch() == TVLaunchSyncResult())
}
