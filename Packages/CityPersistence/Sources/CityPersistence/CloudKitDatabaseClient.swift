import CloudKit
import Foundation
import os

/// `CloudKitClient` backed by the private database of the app's iCloud
/// container. Schema: `Packages/CityPersistence/CloudKitSchema.md`.
public struct CloudKitDatabaseClient: CloudKitClient {
    public static let containerIdentifier = "iCloud.com.cedricziel.citybuilder"

    enum Field {
        static let recordType = "CitySave"
        static let gameID = "gameID"
        static let body = "body"
        static let currentDevice = "currentDevice"
    }

    private static let logger = Logger(subsystem: "com.cedricziel.citybuilder", category: "CloudKit")

    private let container: CKContainer

    public init(container: CKContainer = CKContainer(identifier: containerIdentifier)) {
        self.container = container
    }

    private var database: CKDatabase {
        container.privateCloudDatabase
    }

    public func upload(
        gameID: UUID,
        body: Data,
        deviceID: String,
        expecting: UploadExpectation
    ) async throws -> CloudRecord {
        let bodyURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("CitySave-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: bodyURL) }

        do {
            try body.write(to: bodyURL)
            let record = try await recordToSave(gameID: gameID, expecting: expecting)
            Self.setFields(on: record, gameID: gameID, bodyURL: bodyURL, deviceID: deviceID)
            // With an expectation, the server refuses the save if the record
            // changed since it was read (serverRecordChanged).
            let (saveResults, _) = try await database.modifyRecords(
                saving: [record],
                deleting: [],
                savePolicy: expecting == .anyRecord ? .allKeys : .ifServerRecordUnchanged
            )
            guard let result = saveResults[record.recordID] else {
                throw SyncError.failed("CloudKit returned no result for \(record.recordID.recordName)")
            }
            let summary = try Self.summary(from: result.get())
            return CloudRecord(
                gameID: summary.gameID,
                body: body,
                modificationDate: summary.modificationDate,
                currentDevice: summary.currentDevice,
                changeTag: summary.changeTag
            )
        } catch {
            throw Self.syncError(from: error)
        }
    }

    /// The record an upload saves into. For `.changeTag`, that is the
    /// server's record, fetched without its fields, so the save carries the
    /// change tag the server checks.
    private func recordToSave(gameID: UUID, expecting: UploadExpectation) async throws -> CKRecord {
        let recordID = Self.recordID(for: gameID)
        guard case let .changeTag(tag) = expecting else {
            return CKRecord(recordType: Field.recordType, recordID: recordID)
        }
        let fetched = try await database.records(for: [recordID], desiredKeys: [])
        switch fetched[recordID] {
        case let .success(server)? where server.recordChangeTag == tag:
            return server
        case let .failure(error)? where (error as? CKError)?.code != .unknownItem:
            throw error
        default:
            // Changed, or deleted, since it was listed.
            throw SyncError.recordChanged
        }
    }

    public func fetchLatest(gameID: UUID) async throws -> CloudRecord? {
        do {
            let record = try await database.record(for: Self.recordID(for: gameID))
            return try Self.cloudRecord(from: record)
        } catch let error as CKError where error.code == .unknownItem {
            return nil
        } catch {
            throw Self.syncError(from: error)
        }
    }

    public func listGames() async throws -> [CloudRecordSummary] {
        let desiredKeys = [Field.gameID, Field.currentDevice]
        let query = CKQuery(recordType: Field.recordType, predicate: NSPredicate(value: true))
        do {
            var results: [Result<CKRecord, Error>] = []
            var page = try await database.records(matching: query, desiredKeys: desiredKeys)
            while true {
                results += page.matchResults.map(\.1)
                guard let cursor = page.queryCursor else { break }
                page = try await database.records(continuingMatchFrom: cursor, desiredKeys: desiredKeys)
            }
            return try Self.summaries(from: results)
        } catch let error as CKError where error.code == .unknownItem {
            // CloudKit has no CitySave record type until the first upload creates it.
            return []
        } catch {
            throw Self.syncError(from: error)
        }
    }

    public func isAccountAvailable() async -> Bool {
        await (try? container.accountStatus()) == .available
    }

    func delete(gameID: UUID) async throws {
        do {
            _ = try await database.deleteRecord(withID: Self.recordID(for: gameID))
        } catch let error as CKError where error.code == .unknownItem {
            return
        } catch {
            throw Self.syncError(from: error)
        }
    }

    static func recordID(for gameID: UUID) -> CKRecord.ID {
        CKRecord.ID(recordName: gameID.uuidString, zoneID: CKRecordZone.default().zoneID)
    }

    static func setFields(on record: CKRecord, gameID: UUID, bodyURL: URL, deviceID: String) {
        record[Field.gameID] = gameID.uuidString
        record[Field.body] = CKAsset(fileURL: bodyURL)
        record[Field.currentDevice] = deviceID
    }

    static func summary(from record: CKRecord) throws -> CloudRecordSummary {
        let name = record.recordID.recordName
        guard
            let idString = record[Field.gameID] as? String,
            let gameID = UUID(uuidString: idString)
        else {
            throw SyncError.failed("CitySave record \(name) has no valid gameID")
        }
        guard gameID.uuidString == name else {
            throw SyncError.failed("CitySave record \(name) has gameID \(idString)")
        }
        guard let currentDevice = record[Field.currentDevice] as? String else {
            throw SyncError.failed("CitySave record \(name) has no currentDevice")
        }
        guard let modificationDate = record.modificationDate else {
            throw SyncError.failed("CitySave record \(name) has no modification date")
        }
        return CloudRecordSummary(
            gameID: gameID,
            modificationDate: modificationDate,
            currentDevice: currentDevice,
            changeTag: record.recordChangeTag
        )
    }

    static func summaries(
        from results: [Result<CKRecord, Error>],
        summarize: (CKRecord) throws -> CloudRecordSummary = summary(from:)
    ) throws -> [CloudRecordSummary] {
        try results
            .compactMap { result in
                let record = try result.get()
                do {
                    return try summarize(record)
                } catch {
                    logger.error("Skipping unreadable CitySave record: \(error.localizedDescription)")
                    return nil
                }
            }
            .sortedByGameID()
    }

    static func cloudRecord(from record: CKRecord) throws -> CloudRecord {
        let summary = try summary(from: record)
        guard
            let asset = record[Field.body] as? CKAsset,
            let fileURL = asset.fileURL
        else {
            throw SyncError.failed("CitySave record \(record.recordID.recordName) has no body")
        }
        return try CloudRecord(
            gameID: summary.gameID,
            body: Data(contentsOf: fileURL),
            modificationDate: summary.modificationDate,
            currentDevice: summary.currentDevice,
            changeTag: summary.changeTag
        )
    }

    static func syncError(from error: Error) -> SyncError {
        if let syncError = error as? SyncError { return syncError }
        guard let ckError = error as? CKError else { return .failed(error.localizedDescription) }
        switch ckError.code {
        case .notAuthenticated, .accountTemporarilyUnavailable:
            return .notSignedIn
        case .networkUnavailable, .networkFailure, .serviceUnavailable:
            return .offline
        case .serverRecordChanged:
            return .recordChanged
        default:
            return .failed(ckError.localizedDescription)
        }
    }
}
