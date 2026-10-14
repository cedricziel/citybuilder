import Foundation

/// What a launch sync did: games downloaded because they had no local
/// copy, and games whose remote copy is newer than the local one. A
/// conflict is never overwritten here; the player decides.
public struct TVLaunchSyncResult: Equatable, Sendable {
    public var restored: [UUID] = []
    public var conflicts: [UUID] = []
}

/// Keeps Apple TV saves in iCloud. Apple TV saves live in Caches, which
/// the system may purge, so every save is uploaded as soon as it is
/// written. Uploads that fail stay on a pending list in `UserDefaults`
/// and are retried at the next save, at launch and when the app becomes
/// active. At launch, games that exist only in iCloud are downloaded.
/// Spec: `icloud-sync` / Apple TV keeps saves in iCloud.
public actor TVSaveSync {
    static let pendingUploadsKey = "tvSaveSync.pendingUploads"

    private let store: SaveStore
    private let client: CloudKitClient
    private let deviceID: String
    private let defaults: UserDefaults

    /// `defaultsSuite` names the `UserDefaults` suite that holds the
    /// pending list; nil uses the standard defaults.
    public init(store: SaveStore, client: CloudKitClient, deviceID: String, defaultsSuite: String? = nil) {
        self.store = store
        self.client = client
        self.deviceID = deviceID
        defaults = defaultsSuite.flatMap(UserDefaults.init(suiteName:)) ?? .standard
    }

    public var pendingUploads: Set<UUID> {
        Set((defaults.stringArray(forKey: Self.pendingUploadsKey) ?? []).compactMap(UUID.init(uuidString:)))
    }

    /// Call after every save the game writes.
    public func didSave(gameID: UUID) async {
        setPendingUploads(pendingUploads.union([gameID]))
        await retryPendingUploads()
    }

    /// Uploads every pending save; the ones that still fail stay pending.
    public func retryPendingUploads() async {
        var stillPending = Set<UUID>()
        for gameID in pendingUploads where await !upload(gameID: gameID) {
            stillPending.insert(gameID)
        }
        setPendingUploads(stillPending)
    }

    /// Run at launch, before the title screen lists saves.
    public func launch() async -> TVLaunchSyncResult {
        await retryPendingUploads()
        guard let remote = try? await client.listGames() else { return TVLaunchSyncResult() }
        let localDates = Dictionary(uniqueKeysWithValues: ((try? store.listSaves()) ?? []).map { ($0.gameID, $0.writeDate) })
        var result = TVLaunchSyncResult()
        var newerLocal = Set<UUID>()
        for record in remote {
            let local = localDates[record.gameID].map { Self.matches($0, record.modificationDate) ? record.modificationDate : $0 }
            switch ConflictPolicy.decide(local: local, remote: record.modificationDate) {
            case .acceptRemote(askUser: false):
                if await restore(gameID: record.gameID) {
                    result.restored.append(record.gameID)
                }
            case .acceptRemote(askUser: true):
                result.conflicts.append(record.gameID)
            case .uploadLocal:
                newerLocal.insert(record.gameID)
            case .noOp:
                break
            }
        }
        if !newerLocal.isEmpty {
            setPendingUploads(pendingUploads.union(newerLocal))
            await retryPendingUploads()
        }
        return result
    }

    public func isAccountAvailable() async -> Bool {
        await client.isAccountAvailable()
    }

    /// Settles a launch conflict: keeping iCloud replaces the local save,
    /// keeping the local save replaces the iCloud copy.
    public func resolveConflict(gameID: UUID, keepICloud: Bool) async {
        if keepICloud {
            _ = await restore(gameID: gameID)
        } else {
            await didSave(gameID: gameID)
        }
    }

    private func upload(gameID: UUID) async -> Bool {
        guard let body = try? store.writer.read(from: store.url(for: gameID)) else {
            // The local file is gone, so there is nothing left to upload.
            return true
        }
        guard let record = try? await client.upload(gameID: gameID, body: body, deviceID: deviceID) else { return false }
        markSynced(gameID: gameID, at: record.modificationDate)
        return true
    }

    private func restore(gameID: UUID) async -> Bool {
        guard let record = try? await client.fetchLatest(gameID: gameID),
              (try? store.decode(record.body)) != nil
        else { return false }
        guard (try? store.writer.write(record.body, to: store.url(for: gameID))) != nil else { return false }
        markSynced(gameID: gameID, at: record.modificationDate)
        return true
    }

    /// A synced local file carries its record's modification date, so the
    /// next launch sees the two copies as equal rather than as a conflict.
    private func markSynced(gameID: UUID, at date: Date) {
        try? FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: store.url(for: gameID).path)
    }

    /// File-system timestamps do not round-trip a `Date` exactly, so dates
    /// within a second of each other count as the same write.
    private static func matches(_ lhs: Date, _ rhs: Date) -> Bool {
        abs(lhs.timeIntervalSince(rhs)) < 1
    }

    private func setPendingUploads(_ ids: Set<UUID>) {
        defaults.set(ids.map(\.uuidString).sorted(), forKey: Self.pendingUploadsKey)
    }
}
