import Foundation
import Synchronization

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
                guard let seen = sync.conflictVersions[gameID], Self.isSameRecord(seen, current) else {
                    sync.conflictVersions[gameID] = current
                    return .superseded
                }
                // The player chose the local save over this iCloud copy.
                sync.setSynced(current.modificationDate, changeTag: current.changeTag, for: gameID)
            }
            sync.conflictVersions[gameID] = nil
            sync.addPendingUploads([gameID])
            await sync.uploadPending(remote: remote)
            return .resolved
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
                conflictVersions[gameID] = remote[gameID]
                result.conflicts.append(gameID)
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
    /// meanwhile stays on it.
    private func uploadPending(remote: [UUID: CloudRecordSummary]) async {
        var settled = Set<UUID>()
        for gameID in pendingUploads.sorted() where await upload(gameID: gameID, remote: remote[gameID]) {
            settled.insert(gameID)
        }
        setPendingUploads(pendingUploads.subtracting(settled))
    }

    /// Returns true when the game no longer needs an upload. A newer
    /// iCloud copy, a failed upload and a save written during the upload
    /// all leave it pending.
    private func upload(gameID: UUID, remote: CloudRecordSummary?) async -> Bool {
        // The local file is gone, so there is nothing left to upload.
        guard let local = store.writeDate(gameID: gameID) else { return true }
        switch decide(local: local, remote: remote, isPending: true) {
        case .acceptRemote:
            conflictVersions[gameID] = remote
            return false
        case .noOp: return true
        case .uploadLocal: break
        }
        let deviceID = deviceID
        guard let body = try? store.writer.read(from: store.url(for: gameID)),
              let record = try? await call({ try await $0.upload(gameID: gameID, body: body, deviceID: deviceID) })
        else { return false }
        setSynced(record.modificationDate, changeTag: record.changeTag, for: gameID)
        guard store.writeDate(gameID: gameID) == local else { return false }
        markSynced(gameID: gameID, at: record.modificationDate)
        return true
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

    /// Runs one CloudKit call, giving up with `SyncError.offline` after
    /// `callTimeout`, and cancels it. A call that ignores cancellation is
    /// left to finish on its own.
    private func call<T: Sendable>(_ operation: @escaping @Sendable (CloudKitClient) async throws -> T) async throws -> T {
        let client = client
        let timeout = callTimeout
        return try await withCheckedThrowingContinuation { continuation in
            let resumer = ResumeOnce(continuation)
            let work = Task {
                do {
                    try await resumer.resume(with: .success(operation(client)))
                } catch {
                    resumer.resume(with: .failure(error))
                }
            }
            Task {
                try? await Task.sleep(for: timeout)
                resumer.resume(with: .failure(SyncError.offline))
                work.cancel()
            }
        }
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

/// Resumes a continuation once; later results are dropped.
private final class ResumeOnce<T: Sendable>: Sendable {
    private let continuation: Mutex<CheckedContinuation<T, Error>?>

    init(_ continuation: CheckedContinuation<T, Error>) {
        self.continuation = Mutex(continuation)
    }

    func resume(with result: Result<T, Error>) {
        continuation.withLock { $0.take() }?.resume(with: result)
    }
}
