import Foundation
import Testing
@testable import CityPersistence

// Live tests against the development environment of the real container.
// They run only when CITYBUILDER_CLOUDKIT_TESTS=1 is set and the test host
// carries the iCloud entitlement. See README "CloudKit live tests".

private let liveTestsEnabled = ProcessInfo.processInfo.environment["CITYBUILDER_CLOUDKIT_TESTS"] == "1"

@Suite(.enabled(if: liveTestsEnabled), .serialized)
struct CloudKitLiveTests {
    let client = CloudKitDatabaseClient()

    private func withGame(_ body: (UUID) async throws -> Void) async throws {
        let gameID = UUID()
        do {
            try await body(gameID)
        } catch {
            try? await client.delete(gameID: gameID)
            throw error
        }
        try await client.delete(gameID: gameID)
    }

    /// Queries are eventually consistent, so a fresh upload can take a moment to be listed.
    private func listed(
        _ gameID: UUID,
        matching predicate: (CloudRecordSummary) -> Bool
    ) async throws -> [CloudRecordSummary] {
        for _ in 0 ..< 10 {
            let entries = try await client.listGames().filter { $0.gameID == gameID }
            if entries.contains(where: predicate) { return entries }
            try await Task.sleep(for: .seconds(1))
        }
        return try await client.listGames().filter { $0.gameID == gameID }
    }

    @Test("live: upload then fetch returns the same body")
    func uploadThenFetch() async throws {
        try await withGame { gameID in
            let body = Data((0 ..< 4096).map { UInt8(truncatingIfNeeded: $0 &* 7) })
            _ = try await client.upload(gameID: gameID, body: body, deviceID: "live-test")
            let fetched = try #require(try await client.fetchLatest(gameID: gameID))
            #expect(fetched.body == body)
            #expect(fetched.currentDevice == "live-test")
        }
    }

    @Test("live: fetch of an unknown game is nil")
    func fetchUnknown() async throws {
        #expect(try await client.fetchLatest(gameID: UUID()) == nil)
    }

    @Test("live: uploaded game is listed")
    func uploadedGameIsListed() async throws {
        try await withGame { gameID in
            let record = try await client.upload(gameID: gameID, body: Data("list".utf8), deviceID: "live-test")
            let entries = try await listed(gameID) { $0.modificationDate == record.modificationDate }
            #expect(entries.count == 1)
            #expect(entries.first?.currentDevice == "live-test")
        }
    }

    @Test("live: second upload replaces the record")
    func secondUploadReplaces() async throws {
        try await withGame { gameID in
            _ = try await client.upload(gameID: gameID, body: Data("one".utf8), deviceID: "live-a")
            let second = try await client.upload(gameID: gameID, body: Data("two".utf8), deviceID: "live-b")
            let entries = try await listed(gameID) { $0.modificationDate == second.modificationDate }
            #expect(entries.count == 1)
            #expect(entries.first?.currentDevice == "live-b")
            let fetched = try await client.fetchLatest(gameID: gameID)
            #expect(fetched?.body == Data("two".utf8))
        }
    }
}
