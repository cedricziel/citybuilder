import Foundation
import Testing
@testable import CityPersistence

// Tests for spec `icloud-sync` — `List the user's save records` and
// `Save records round-trip through the private database` requirements.

@Test("scenario: listing returns every uploaded game")
func scenarioListingReturnsEveryUploadedGame() async throws {
    let client = InMemoryCloudKitClient(accountAvailable: true)
    let gameA = UUID()
    let gameB = UUID()
    let recordA = try await client.upload(gameID: gameA, body: Data("a".utf8), deviceID: "iPad")
    let recordB = try await client.upload(gameID: gameB, body: Data("b".utf8), deviceID: "Mac")

    let listed = try await client.listGames()

    #expect(listed.count == 2)
    let byID = Dictionary(uniqueKeysWithValues: listed.map { ($0.gameID, $0) })
    #expect(byID[gameA] == CloudRecordSummary(
        gameID: gameA,
        modificationDate: recordA.modificationDate,
        currentDevice: "iPad"
    ))
    #expect(byID[gameB] == CloudRecordSummary(
        gameID: gameB,
        modificationDate: recordB.modificationDate,
        currentDevice: "Mac"
    ))
}

@Test("scenario: listing with no records is empty")
func scenarioListingWithNoRecordsIsEmpty() async throws {
    let client = InMemoryCloudKitClient(accountAvailable: true)
    let listed = try await client.listGames()
    #expect(listed.isEmpty)
}

@Test("scenario: listing without an account fails")
func scenarioListingWithoutAnAccountFails() async {
    let client = InMemoryCloudKitClient(accountAvailable: false)
    await #expect(throws: SyncError.notSignedIn) {
        _ = try await client.listGames()
    }
}

@Test("scenario: uploaded body fetches back unchanged")
func scenarioUploadedBodyFetchesBackUnchanged() async throws {
    let client = InMemoryCloudKitClient(accountAvailable: true)
    let gameID = UUID()
    let body = Data((0 ..< 1024).map { UInt8(truncatingIfNeeded: $0 &* 31) })

    _ = try await client.upload(gameID: gameID, body: body, deviceID: "iPhone")
    let fetched = try #require(try await client.fetchLatest(gameID: gameID))

    #expect(fetched.body == body)
    #expect(fetched.currentDevice == "iPhone")
}

@Test("scenario: second upload replaces the record")
func scenarioSecondUploadReplacesTheRecord() async throws {
    let client = InMemoryCloudKitClient(accountAvailable: true)
    let gameID = UUID()
    _ = try await client.upload(gameID: gameID, body: Data("first".utf8), deviceID: "iPad")
    let second = try await client.upload(gameID: gameID, body: Data("second".utf8), deviceID: "Mac")

    let listed = try await client.listGames()

    #expect(listed == [CloudRecordSummary(
        gameID: gameID,
        modificationDate: second.modificationDate,
        currentDevice: "Mac"
    )])
}
