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
/// active. At launch, games that exist only in iCloud are downloaded and
/// games that exist only on this device are uploaded.
///
/// Every Apple TV on an account shares one game ID, so an upload never
/// replaces a newer iCloud copy: that game is reported as a conflict and
/// stays pending until the player resolves it. Sync passes run one at a
/// time, in call order.
/// Spec: `icloud-sync` / Apple TV keeps saves in iCloud.
public actor TVSaveSync {
    static let pendingUploadsKey = "tvSaveSync.pendingUploads"
    static let syncedDatesKey = "tvSaveSync.syncedDates"

    private let store: SaveStore
    private let client: CloudKitClient
    private let deviceID: String
    private let defaults: UserDefaults
    private var lastPass: Task<Void, Never>?

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
        addPendingUploads([gameID])
        await retryPendingUploads()
    }

    /// Uploads every pending save whose iCloud copy is not newer. Saves
    /// whose iCloud copy is newer stay pending, as do uploads that fail.
    public func retryPendingUploads() async {
        await serialized { sync in
            guard !sync.pendingUploads.isEmpty, let remote = try? await sync.remoteDates() else { return }
            await sync.uploadPending(remote: remote)
        }
    }

    /// Run at launch, before the title screen lists saves.
    public func launch() async -> TVLaunchSyncResult {
        await serialized { await $0.launchPass() }
    }

    public func isAccountAvailable() async -> Bool {
        await client.isAccountAvailable()
    }

    /// Settles a launch conflict: keeping iCloud replaces the local save,
    /// keeping the local save replaces the iCloud copy. Returns false when
    /// iCloud could not be reached, so the conflict still stands. A failed
    /// upload of the kept local save stays pending.
    public func resolveConflict(gameID: UUID, keepICloud: Bool) async -> Bool {
        await serialized { sync in
            if keepICloud {
                return await sync.restore(gameID: gameID)
            }
            guard let remote = try? await sync.remoteDates() else { return false }
            // The player chose the local save over this iCloud copy.
            if let date = remote[gameID] {
                sync.setSyncedDate(date, for: gameID)
            }
            sync.addPendingUploads([gameID])
            await sync.uploadPending(remote: remote)
            return true
        }
    }

    /// Runs `work` after every pass that was started before it.
    private func serialized<T: Sendable>(_ work: @escaping @Sendable (isolated TVSaveSync) async -> T) async -> T {
        let previous = lastPass
        let pass = Task {
            await previous?.value
            return await work(self)
        }
        lastPass = Task { _ = await pass.value }
        return await pass.value
    }

    private func launchPass() async -> TVLaunchSyncResult {
        guard let remote = try? await remoteDates() else { return TVLaunchSyncResult() }
        let local = Dictionary(uniqueKeysWithValues: ((try? store.listSaves()) ?? []).map { ($0.gameID, $0.writeDate) })
        var result = TVLaunchSyncResult()
        var newerLocal: [UUID] = []
        let pending = pendingUploads
        for gameID in Set(remote.keys).union(local.keys).sorted() {
            switch decide(gameID: gameID, local: local[gameID], remote: remote[gameID], isPending: pending.contains(gameID)) {
            case .acceptRemote(askUser: false):
                if await restore(gameID: gameID) {
                    result.restored.append(gameID)
                }
            case .acceptRemote(askUser: true):
                result.conflicts.append(gameID)
            case .uploadLocal:
                newerLocal.append(gameID)
            case .noOp:
                break
            }
        }
        addPendingUploads(newerLocal)
        await uploadPending(remote: remote)
        return result
    }

    /// One upload pass against the iCloud dates listed for it. Only games
    /// that were settled leave the pending list, so a save added meanwhile
    /// stays on it.
    private func uploadPending(remote: [UUID: Date]) async {
        var settled = Set<UUID>()
        for gameID in pendingUploads.sorted() where await upload(gameID: gameID, remote: remote[gameID]) {
            settled.insert(gameID)
        }
        setPendingUploads(pendingUploads.subtracting(settled))
    }

    /// Returns true when the game no longer needs an upload. A newer
    /// iCloud copy, a failed upload and a save written during the upload
    /// all leave it pending.
    private func upload(gameID: UUID, remote: Date?) async -> Bool {
        // The local file is gone, so there is nothing left to upload.
        guard let local = store.writeDate(gameID: gameID) else { return true }
        switch decide(gameID: gameID, local: local, remote: remote, isPending: true) {
        case .acceptRemote: return false
        case .noOp: return true
        case .uploadLocal: break
        }
        guard let body = try? store.writer.read(from: store.url(for: gameID)),
              let record = try? await client.upload(gameID: gameID, body: body, deviceID: deviceID)
        else { return false }
        setSyncedDate(record.modificationDate, for: gameID)
        guard store.writeDate(gameID: gameID) == local else { return false }
        markSynced(gameID: gameID, at: record.modificationDate)
        return true
    }

    private func restore(gameID: UUID) async -> Bool {
        guard let record = try? await client.fetchLatest(gameID: gameID),
              (try? store.decode(record.body)) != nil
        else { return false }
        guard (try? store.writer.write(record.body, to: store.url(for: gameID))) != nil else { return false }
        setSyncedDate(record.modificationDate, for: gameID)
        markSynced(gameID: gameID, at: record.modificationDate)
        setPendingUploads(pendingUploads.subtracting([gameID]))
        return true
    }

    /// `ConflictPolicy`, plus what it cannot see: whether the iCloud copy
    /// is still the one this device last synced. If it is, a local save
    /// that is pending or differs from it was written after it, even when
    /// its file date is earlier than the record's (a save written while
    /// its upload was in flight).
    private func decide(gameID: UUID, local: Date?, remote: Date?, isPending: Bool) -> SyncDecision {
        if let local, let remote {
            let remoteIsLastSynced = syncedDates[gameID.uuidString].map { Self.matches($0, remote) } ?? false
            let localMatchesRemote = Self.matches(local, remote)
            if remoteIsLastSynced, isPending || !localMatchesRemote { return .uploadLocal }
            if localMatchesRemote { return .noOp }
        }
        return ConflictPolicy.decide(local: local, remote: remote)
    }

    private func remoteDates() async throws -> [UUID: Date] {
        try await Dictionary(client.listGames().map { ($0.gameID, $0.modificationDate) }, uniquingKeysWith: max)
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

    /// The record date of each game's last upload or download on this device.
    private var syncedDates: [String: Date] {
        defaults.dictionary(forKey: Self.syncedDatesKey) as? [String: Date] ?? [:]
    }

    private func setSyncedDate(_ date: Date, for gameID: UUID) {
        var dates = syncedDates
        dates[gameID.uuidString] = date
        defaults.set(dates, forKey: Self.syncedDatesKey)
    }

    private func addPendingUploads(_ ids: [UUID]) {
        guard !ids.isEmpty else { return }
        setPendingUploads(pendingUploads.union(ids))
    }

    private func setPendingUploads(_ ids: Set<UUID>) {
        defaults.set(ids.map(\.uuidString).sorted(), forKey: Self.pendingUploadsKey)
    }
}
