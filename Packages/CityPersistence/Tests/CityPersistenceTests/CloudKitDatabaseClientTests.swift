import CloudKit
import Foundation
import Testing
@testable import CityPersistence

@Test(
    "account errors map to not signed in",
    arguments: [CKError.Code.notAuthenticated, .accountTemporarilyUnavailable]
)
func accountErrorsMapToNotSignedIn(code: CKError.Code) {
    #expect(CloudKitDatabaseClient.syncError(from: CKError(code)) == .notSignedIn)
}

@Test(
    "network and service errors map to offline",
    arguments: [CKError.Code.networkUnavailable, .networkFailure, .serviceUnavailable]
)
func networkErrorsMapToOffline(code: CKError.Code) {
    #expect(CloudKitDatabaseClient.syncError(from: CKError(code)) == .offline)
}

@Test("other CloudKit errors map to failed with their description")
func otherErrorsMapToFailed() {
    let error = CKError(.quotaExceeded)
    #expect(CloudKitDatabaseClient.syncError(from: error) == .failed(error.localizedDescription))
}

@Test("sync errors pass through unchanged")
func syncErrorsPassThrough() {
    #expect(CloudKitDatabaseClient.syncError(from: SyncError.offline) == .offline)
}

@Test("upload record is keyed by game ID and carries asset and device")
func uploadRecordIsKeyedByGameID() throws {
    let gameID = UUID()
    let bodyURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let record = CloudKitDatabaseClient.makeRecord(gameID: gameID, bodyURL: bodyURL, deviceID: "iPad")

    #expect(record.recordType == "CitySave")
    #expect(record.recordID.recordName == gameID.uuidString)
    #expect(record.recordID.zoneID == CKRecordZone.default().zoneID)
    #expect(record["gameID"] as? String == gameID.uuidString)
    #expect(record["currentDevice"] as? String == "iPad")
    let asset = try #require(record["body"] as? CKAsset)
    #expect(asset.fileURL == bodyURL)
}

@Test("record without a modification date is rejected")
func recordWithoutModificationDateIsRejected() {
    let gameID = UUID()
    let record = CKRecord(recordType: "CitySave", recordID: CloudKitDatabaseClient.recordID(for: gameID))
    record["gameID"] = gameID.uuidString
    record["currentDevice"] = "Mac"
    #expect(throws: SyncError.failed("CitySave record \(gameID.uuidString) has no modification date")) {
        _ = try CloudKitDatabaseClient.summary(from: record)
    }
}

@Test("record with a malformed game ID is rejected")
func recordWithMalformedGameIDIsRejected() {
    let record = CKRecord(recordType: "CitySave")
    record["gameID"] = "not-a-uuid"
    record["currentDevice"] = "Mac"
    #expect(throws: SyncError.self) {
        _ = try CloudKitDatabaseClient.summary(from: record)
    }
}

@Test("listing skips records that fail and sorts the rest by game ID")
func listingSkipsFailedRecordsAndSorts() throws {
    let first = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000001"))
    let second = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000002"))
    let date = Date(timeIntervalSince1970: 1000)
    let results: [Result<CKRecord, Error>] = [
        .success(CKRecord(recordType: "CitySave", recordID: CloudKitDatabaseClient.recordID(for: second))),
        .failure(CKError(.permissionFailure)),
        .success(CKRecord(recordType: "CitySave", recordID: CKRecord.ID(recordName: "broken"))),
        .success(CKRecord(recordType: "CitySave", recordID: CloudKitDatabaseClient.recordID(for: first)))
    ]

    let summaries = CloudKitDatabaseClient.summaries(from: results) { record in
        guard let gameID = UUID(uuidString: record.recordID.recordName) else {
            throw SyncError.failed("broken")
        }
        return CloudRecordSummary(gameID: gameID, modificationDate: date, currentDevice: "Mac")
    }

    #expect(summaries.map(\.gameID) == [first, second])
}
