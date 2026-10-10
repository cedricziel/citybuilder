import CloudKit
import Foundation

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

    private let container: CKContainer

    public init(container: CKContainer = CKContainer(identifier: containerIdentifier)) {
        self.container = container
    }

    private var database: CKDatabase {
        container.privateCloudDatabase
    }

    public func upload(gameID: UUID, body: Data, deviceID: String) async throws -> CloudRecord {
        let bodyURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("CitySave-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: bodyURL) }

        do {
            try body.write(to: bodyURL)
            let record = Self.makeRecord(gameID: gameID, bodyURL: bodyURL, deviceID: deviceID)
            let (saveResults, _) = try await database.modifyRecords(
                saving: [record],
                deleting: [],
                savePolicy: .allKeys
            )
            guard let result = saveResults[record.recordID] else {
                throw SyncError.failed("CloudKit returned no result for \(record.recordID.recordName)")
            }
            let summary = try Self.summary(from: result.get())
            return CloudRecord(
                gameID: summary.gameID,
                body: body,
                modificationDate: summary.modificationDate,
                currentDevice: summary.currentDevice
            )
        } catch {
            throw Self.syncError(from: error)
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
            var summaries: [CloudRecordSummary] = []
            var page = try await database.records(matching: query, desiredKeys: desiredKeys)
            while true {
                for (_, result) in page.matchResults {
                    try summaries.append(Self.summary(from: result.get()))
                }
                guard let cursor = page.queryCursor else { break }
                page = try await database.records(continuingMatchFrom: cursor, desiredKeys: desiredKeys)
            }
            return summaries
        } catch {
            throw Self.syncError(from: error)
        }
    }

    public func isAccountAvailable() async -> Bool {
        await (try? container.accountStatus()) == .available
    }

    static func recordID(for gameID: UUID) -> CKRecord.ID {
        CKRecord.ID(recordName: gameID.uuidString, zoneID: CKRecordZone.default().zoneID)
    }

    static func makeRecord(gameID: UUID, bodyURL: URL, deviceID: String) -> CKRecord {
        let record = CKRecord(recordType: Field.recordType, recordID: recordID(for: gameID))
        record[Field.gameID] = gameID.uuidString
        record[Field.body] = CKAsset(fileURL: bodyURL)
        record[Field.currentDevice] = deviceID
        return record
    }

    static func summary(from record: CKRecord) throws -> CloudRecordSummary {
        let name = record.recordID.recordName
        guard
            let idString = record[Field.gameID] as? String,
            let gameID = UUID(uuidString: idString)
        else {
            throw SyncError.failed("CitySave record \(name) has no valid gameID")
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
            currentDevice: currentDevice
        )
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
            currentDevice: summary.currentDevice
        )
    }

    static func syncError(from error: Error) -> SyncError {
        if let syncError = error as? SyncError { return syncError }
        guard let ckError = error as? CKError else { return .failed(error.localizedDescription) }
        switch ckError.code {
        case .notAuthenticated:
            return .notSignedIn
        case .networkUnavailable, .networkFailure, .serviceUnavailable:
            return .offline
        default:
            return .failed(ckError.localizedDescription)
        }
    }
}
