import CityCore
import Foundation

/// Abstraction over CloudKit so tests use a fast in-memory fake while
/// production talks to the real CKContainer. Per design D13, real CloudKit
/// tests are gated behind CITYBUILDER_CLOUDKIT_TESTS=1.
public protocol CloudKitClient: Sendable {
    func upload(gameID: UUID, body: Data, deviceID: String) async throws -> CloudRecord
    func fetchLatest(gameID: UUID) async throws -> CloudRecord?
    /// Every save record in the user's private database, sorted by game ID.
    func listGames() async throws -> [CloudRecordSummary]
    func isAccountAvailable() async -> Bool
}

/// `changeTag` identifies one version of a record: it changes on every
/// save, so two records with equal tags are the same upload.
public struct CloudRecord: Hashable, Sendable {
    public let gameID: UUID
    public let body: Data
    public let modificationDate: Date
    public let currentDevice: String
    public let changeTag: String?

    public init(gameID: UUID, body: Data, modificationDate: Date, currentDevice: String, changeTag: String? = nil) {
        self.gameID = gameID
        self.body = body
        self.modificationDate = modificationDate
        self.currentDevice = currentDevice
        self.changeTag = changeTag
    }
}

public struct CloudRecordSummary: Hashable, Sendable {
    public let gameID: UUID
    public let modificationDate: Date
    public let currentDevice: String
    public let changeTag: String?

    public init(gameID: UUID, modificationDate: Date, currentDevice: String, changeTag: String? = nil) {
        self.gameID = gameID
        self.modificationDate = modificationDate
        self.currentDevice = currentDevice
        self.changeTag = changeTag
    }
}

extension [CloudRecordSummary] {
    func sortedByGameID() -> [CloudRecordSummary] {
        sorted { $0.gameID.uuidString < $1.gameID.uuidString }
    }
}

public enum SyncError: Error, Equatable, Sendable {
    case notSignedIn
    case offline
    case conflict(remote: Date, local: Date)
    case failed(String)
}

public enum SyncDecision: Equatable, Sendable {
    case uploadLocal
    case acceptRemote(askUser: Bool)
    case noOp
}

public enum ConflictPolicy {
    /// Pick a decision given local + remote modification dates. Mirrors
    /// the LWW policy with a UI prompt when overwrite direction differs.
    public static func decide(local: Date?, remote: Date?) -> SyncDecision {
        switch (local, remote) {
        case (.none, .none):
            return .noOp
        case (.some, .none):
            return .uploadLocal
        case (.none, .some):
            return .acceptRemote(askUser: false)
        case let (.some(localDate), .some(remoteDate)):
            if localDate > remoteDate { return .uploadLocal }
            if remoteDate > localDate { return .acceptRemote(askUser: true) }
            return .noOp
        }
    }
}

/// In-memory fake used by unit tests.
public actor InMemoryCloudKitClient: CloudKitClient {
    public private(set) var records: [UUID: CloudRecord] = [:]
    public private(set) var accountAvailable: Bool

    public init(accountAvailable: Bool = true) {
        self.accountAvailable = accountAvailable
    }

    public func setAccountAvailable(_ available: Bool) {
        accountAvailable = available
    }

    public func upload(gameID: UUID, body: Data, deviceID: String) async throws -> CloudRecord {
        guard accountAvailable else { throw SyncError.notSignedIn }
        let record = CloudRecord(
            gameID: gameID,
            body: body,
            modificationDate: Date(),
            currentDevice: deviceID,
            changeTag: UUID().uuidString
        )
        records[gameID] = record
        return record
    }

    public func fetchLatest(gameID: UUID) async throws -> CloudRecord? {
        guard accountAvailable else { throw SyncError.notSignedIn }
        return records[gameID]
    }

    public func listGames() async throws -> [CloudRecordSummary] {
        guard accountAvailable else { throw SyncError.notSignedIn }
        return records.values
            .map {
                CloudRecordSummary(
                    gameID: $0.gameID,
                    modificationDate: $0.modificationDate,
                    currentDevice: $0.currentDevice,
                    changeTag: $0.changeTag
                )
            }
            .sortedByGameID()
    }

    public func isAccountAvailable() async -> Bool {
        accountAvailable
    }
}
