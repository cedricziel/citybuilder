import Foundation

/// How settling a conflict ended. `superseded` means the iCloud copy
/// changed after the player was asked, so the player must choose again.
public enum TVConflictResolution: Equatable, Sendable {
    case resolved
    case unreachable
    case superseded
}

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
/// time, in call order, and every CloudKit call gives up after
/// `callTimeout`.
/// Spec: `icloud-sync` / Apple TV keeps saves in iCloud.
public actor TVSaveSync {
    static let pendingUploadsKey = "tvSaveSync.pendingUploads"
    static let syncedDatesKey = "tvSaveSync.syncedDates"
    static let syncedChangeTagsKey = "tvSaveSync.syncedChangeTags"

    private let store: SaveStore
    private let client: CloudKitClient
    private let deviceID: String
    private let defaults: UserDefaults
    private let callTimeout: Duration
    private var lastPass: Task<Void, Never>?
    private var hasLaunched = false
    /// The iCloud copy each reported conflict was decided against.
    private var conflictVersions: [UUID: CloudRecordSummary] = [:]

    /// `defaultsSuite` names the `UserDefaults` suite that holds the
    /// pending list; nil uses the standard defaults.
    public init(
        store: SaveStore,
        client: CloudKitClient,
        deviceID: String,
        defaultsSuite: String? = nil,
        callTimeout: Duration = .seconds(30)
    ) {
        self.store = store
        self.client = client
        self.deviceID = deviceID
        self.callTimeout = callTimeout
        defaults = defaultsSuite.flatMap(UserDefaults.init(suiteName:)) ?? .standard
    }

    public var pendingUploads: Set<UUID> {
        Set((defaults.stringArray(forKey: Self.pendingUploadsKey) ?? []).compactMap(UUID.init(uuidString:)))
    }

    /// Call after every save the game writes.
    public func didSave(gameID: UUID) async {
        addPendingUploads([gameID])
        await serialized { await $0.uploadPass() }
    }

    /// Uploads every pending save whose iCloud copy is not newer. Saves
    /// whose iCloud copy is newer stay pending, as do uploads that fail.
    /// Does nothing before `launch()`, which uploads them itself.
    public func retryPendingUploads() async {
        guard hasLaunched else { return }
        await serialized { await $0.uploadPass() }
    }

    /// Run at launch, before the title screen lists saves. Returns once
    /// iCloud is listed and missing saves are downloaded; uploads run
    /// after it returns.
    public func launch() async -> TVLaunchSyncResult {
        hasLaunched = true
        let result = await serialized { await $0.launchPass() }
        enqueue { await $0.uploadPass() }
        return result
    }

    public func isAccountAvailable() async -> Bool {
        await client.isAccountAvailable()
    }

    /// Settles a reported conflict: keeping iCloud replaces the local
    /// save, keeping the local save replaces the iCloud copy. Keeping the
    /// local save is `superseded` when the iCloud copy changed after the
    /// conflict was reported, so a save the player never saw is not
    /// replaced. A failed upload of the kept local save stays pending.
    public func resolveConflict(gameID: UUID, keepICloud: Bool) async -> TVConflictResolution {
        await serialized { sync in
            if keepICloud {
                guard await sync.restore(gameID: gameID) else { return .unreachable }
                sync.conflictVersions[gameID] = nil
                return .resolved
            }
            guard let remote = try? await sync.remoteRecords() else { return .unreachable }
            if let current = remote[gameID] {
                guard sync.isKnownConflict(gameID: gameID, remote: current) else {
                    sync.conflictVersions[gameID] = current
                    return .superseded
                }
                // The player chose the local save over this iCloud copy.
                sync.setSynced(current.modificationDate, changeTag: current.changeTag, for: gameID)
            }
            sync.conflictVersions[gameID] = nil
            sync.addPendingUploads([gameID])
            guard await sync.uploadPending(remote: remote).contains(gameID) else { return .resolved }
            // iCloud changed between the listing and the upload.
            sync.conflictVersions[gameID] = try? await sync.remoteRecords()[gameID]
            return .superseded
        }
    }

    /// Returns once every pass started so far has finished.
    func settle() async {
        await serialized { _ in }
    }

    /// Starts `work` after every pass that was started before it.
    @discardableResult
    private func enqueue<T: Sendable>(
        _ work: @escaping @Sendable (isolated TVSaveSync) async -> T
    ) -> Task<T, Never> {
        let previous = lastPass
        let pass = Task {
            await previous?.value
            return await work(self)
        }
        lastPass = Task { _ = await pass.value }
        return pass
    }

    private func serialized<T: Sendable>(_ work: @escaping @Sendable (isolated TVSaveSync) async -> T) async -> T {
        await enqueue(work).value
    }

    private func launchPass() async -> TVLaunchSyncResult {
        guard let remote = try? await remoteRecords() else { return TVLaunchSyncResult() }
        let local = Dictionary(uniqueKeysWithValues: ((try? store.listSaves()) ?? []).map { ($0.gameID, $0.writeDate) })
        var result = TVLaunchSyncResult()
        var newerLocal: [UUID] = []
        let pending = pendingUploads
        for gameID in Set(remote.keys).union(local.keys).sorted() {
            switch decide(local: local[gameID], remote: remote[gameID], isPending: pending.contains(gameID)) {
            case .acceptRemote(askUser: false):
                if await restore(gameID: gameID, unlessSavedLocally: true) {
                    result.restored.append(gameID)
                }
            case .acceptRemote(askUser: true):
                if await adoptIfIdentical(gameID: gameID) == .notOurs {
                    conflictVersions[gameID] = remote[gameID]
                    result.conflicts.append(gameID)
                }
            case .uploadLocal:
                newerLocal.append(gameID)
            case .noOp:
                break
            }
        }
        addPendingUploads(newerLocal)
        return result
    }

    private func uploadPass() async {
        guard !pendingUploads.isEmpty, let remote = try? await remoteRecords() else { return }
        await uploadPending(remote: remote)
    }

    /// One upload pass against the iCloud records listed for it. Only
    /// games that were settled leave the pending list, so a save added
    /// meanwhile stays on it. Returns the games whose upload iCloud refused
    /// because their record changed after the listing.
    @discardableResult
    private func uploadPending(remote: [UUID: CloudRecordSummary]) async -> Set<UUID> {
        var settled = Set<UUID>()
        var refused = Set<UUID>()
        for gameID in pendingUploads.sorted() {
            switch await upload(gameID: gameID, remote: remote[gameID]) {
            case .settled: settled.insert(gameID)
            case .refused: refused.insert(gameID)
            case .pending: break
            }
        }
        setPendingUploads(pendingUploads.subtracting(settled))
        return refused
    }

    private enum UploadOutcome {
        /// Uploaded, or no longer needs an upload.
        case settled
        /// Still needs an upload: a newer iCloud copy, a failure, or a save
        /// written during the upload.
        case pending
        /// iCloud refused it because the record changed after the listing.
        case refused
    }

    /// Uploads only over the listed record, so a record saved after the
    /// listing is never replaced.
    private func upload(gameID: UUID, remote: CloudRecordSummary?) async -> UploadOutcome {
        // The local file is gone, so there is nothing left to upload.
        guard let local = store.writeDate(gameID: gameID) else { return .settled }
        switch decide(local: local, remote: remote, isPending: true) {
        case .acceptRemote:
            if !isKnownConflict(gameID: gameID, remote: remote) {
                switch await adoptIfIdentical(gameID: gameID) {
                case .synced: return .settled
                case .savedSince: return .pending
                case .notOurs: break
                }
            }
            conflictVersions[gameID] = remote
            return .pending
        case .noOp: return .settled
        case .uploadLocal: break
        }
        guard let body = try? store.writer.read(from: store.url(for: gameID)) else { return .pending }
        let deviceID = deviceID
        let expecting = Self.expectation(replacing: remote)
        let record: CloudRecord
        do {
            record = try await call { try await $0.upload(gameID: gameID, body: body, deviceID: deviceID, expecting: expecting) }
        } catch SyncError.recordChanged {
            return .refused
        } catch {
            return .pending
        }
        setSynced(record.modificationDate, changeTag: record.changeTag, for: gameID)
        guard store.writeDate(gameID: gameID) == local else { return .pending }
        markSynced(gameID: gameID, at: record.modificationDate)
        return .settled
    }

    private static func expectation(replacing remote: CloudRecordSummary?) -> UploadExpectation {
        guard let remote else { return .noRecord }
        return remote.changeTag.map(UploadExpectation.changeTag) ?? .anyRecord
    }

    /// Whether a conflict was already reported against `remote`, so its
    /// copy was already compared with the local save.
    private func isKnownConflict(gameID: UUID, remote: CloudRecordSummary?) -> Bool {
        guard let seen = conflictVersions[gameID], let remote else { return false }
        return Self.isSameRecord(seen, remote)
    }

    private enum Adoption {
        /// The iCloud copy is not this device's save: a real conflict.
        case notOurs
        /// The iCloud copy is this device's save; the game is synced.
        case synced
        /// The iCloud copy is this device's save, but a newer save was
        /// written during the download and still needs an upload.
        case savedSince
    }

    /// An iCloud copy that looks newer may be this device's own upload
    /// that timed out but still committed. If its bytes equal the local
    /// save, takes that record as the last synced one.
    private func adoptIfIdentical(gameID: UUID) async -> Adoption {
        guard let writeDate = store.writeDate(gameID: gameID),
              let local = try? store.writer.read(from: store.url(for: gameID)),
              let record = try? await call({ try await $0.fetchLatest(gameID: gameID) }),
              record.body == local
        else { return .notOurs }
        setSynced(record.modificationDate, changeTag: record.changeTag, for: gameID)
        // Saves are written outside this actor, so one may have landed
        // during the download; it stays pending and keeps its own date.
        guard store.writeDate(gameID: gameID) == writeDate else {
            addPendingUploads([gameID])
            return .savedSince
        }
        markSynced(gameID: gameID, at: record.modificationDate)
        setPendingUploads(pendingUploads.subtracting([gameID]))
        return .synced
    }

    /// Downloads the iCloud copy over the local save. With
    /// `unlessSavedLocally`, a local save that appeared during the
    /// download is kept instead.
    private func restore(gameID: UUID, unlessSavedLocally: Bool = false) async -> Bool {
        guard let record = try? await call({ try await $0.fetchLatest(gameID: gameID) }),
              (try? store.decode(record.body)) != nil,
              !unlessSavedLocally || store.writeDate(gameID: gameID) == nil
        else { return false }
        guard (try? store.writer.write(record.body, to: store.url(for: gameID))) != nil else { return false }
        setSynced(record.modificationDate, changeTag: record.changeTag, for: gameID)
        markSynced(gameID: gameID, at: record.modificationDate)
        setPendingUploads(pendingUploads.subtracting([gameID]))
        return true
    }

    /// `ConflictPolicy`, plus what it cannot see: whether the iCloud copy
    /// is still the one this device last synced. If it is, a local save
    /// that is pending or differs from it was written after it, even when
    /// its file date is earlier than the record's (a save written while
    /// its upload was in flight).
    private func decide(local: Date?, remote: CloudRecordSummary?, isPending: Bool) -> SyncDecision {
        if let local, let remote {
            let localMatchesRemote = Self.matches(local, remote.modificationDate)
            if isLastSynced(remote), isPending || !localMatchesRemote { return .uploadLocal }
            if localMatchesRemote { return .noOp }
        }
        return ConflictPolicy.decide(local: local, remote: remote?.modificationDate)
    }

    /// Whether `remote` is the record this device last uploaded or
    /// downloaded. The change tag identifies it exactly; the date is a
    /// fallback for records synced before change tags were stored.
    private func isLastSynced(_ remote: CloudRecordSummary) -> Bool {
        let key = remote.gameID.uuidString
        guard let date = syncedDates[key] else { return false }
        return Self.isSameVersion(date, syncedChangeTags[key], remote.modificationDate, remote.changeTag)
    }

    private static func isSameRecord(_ lhs: CloudRecordSummary, _ rhs: CloudRecordSummary) -> Bool {
        isSameVersion(lhs.modificationDate, lhs.changeTag, rhs.modificationDate, rhs.changeTag)
    }

    /// Change tags identify a record version exactly; dates within a second
    /// are the fallback when either side has no tag.
    private static func isSameVersion(_ lhsDate: Date, _ lhsTag: String?, _ rhsDate: Date, _ rhsTag: String?) -> Bool {
        if let lhsTag, let rhsTag {
            return lhsTag == rhsTag
        }
        return matches(lhsDate, rhsDate)
    }

    private func remoteRecords() async throws -> [UUID: CloudRecordSummary] {
        let records = try await call { try await $0.listGames() }
        return Dictionary(records.map { ($0.gameID, $0) }) { lhs, rhs in
            lhs.modificationDate >= rhs.modificationDate ? lhs : rhs
        }
    }

    /// Runs one CloudKit call with `callTimeout`.
    private func call<T: Sendable>(_ operation: @escaping @Sendable (CloudKitClient) async throws -> T) async throws -> T {
        let client = client
        return try await withTimeout(callTimeout) { try await operation(client) }
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

    /// The record change tag of each game's last upload or download.
    private var syncedChangeTags: [String: String] {
        defaults.dictionary(forKey: Self.syncedChangeTagsKey) as? [String: String] ?? [:]
    }

    private func setSynced(_ date: Date, changeTag: String?, for gameID: UUID) {
        var dates = syncedDates
        dates[gameID.uuidString] = date
        defaults.set(dates, forKey: Self.syncedDatesKey)
        var tags = syncedChangeTags
        tags[gameID.uuidString] = changeTag
        defaults.set(tags, forKey: Self.syncedChangeTagsKey)
    }

    private func addPendingUploads(_ ids: [UUID]) {
        guard !ids.isEmpty else { return }
        setPendingUploads(pendingUploads.union(ids))
    }

    private func setPendingUploads(_ ids: Set<UUID>) {
        defaults.set(ids.map(\.uuidString).sorted(), forKey: Self.pendingUploadsKey)
    }
}
