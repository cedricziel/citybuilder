import CloudKit
import Foundation
import Testing
@testable import CityPersistence

@Test("not authenticated maps to not signed in")
func notAuthenticatedMapsToNotSignedIn() {
    let error = CKError(.notAuthenticated)
    #expect(CloudKitDatabaseClient.syncError(from: error) == .notSignedIn)
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
    let record = CloudKitDatabaseClient.makeRecord(
        gameID: gameID,
        bodyURL: FileManager.default.temporaryDirectory,
        deviceID: "Mac"
    )
    #expect(throws: SyncError.self) {
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
