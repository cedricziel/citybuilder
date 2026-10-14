import CityCore
import Foundation
import Testing
@testable import CityPersistence

// Fakes and helpers shared by the TVSaveSync tests.

struct Harness {
    let store: SaveStore
    let client: InMemoryCloudKitClient
    let defaultsSuite = "citybuilder-tvsync-\(UUID().uuidString)"

    /// Pass `client` to put a second Apple TV on the same iCloud account.
    init(accountAvailable: Bool = true, client: InMemoryCloudKitClient? = nil) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("citybuilder-tvsync-\(UUID().uuidString)")
        store = SaveStore(baseDirectory: directory)
        self.client = client ?? InMemoryCloudKitClient(accountAvailable: accountAvailable)
    }

    /// A fresh coordinator over the same disk, cloud and defaults, as on
    /// a relaunch.
    func launchSync(client: (any CloudKitClient)? = nil, callTimeout: Duration = .seconds(30)) -> TVSaveSync {
        TVSaveSync(
            store: store,
            client: client ?? self.client,
            deviceID: "Apple TV",
            defaultsSuite: defaultsSuite,
            callTimeout: callTimeout
        )
    }

    func bytes(of gameID: UUID) throws -> Data {
        try store.writer.read(from: store.url(for: gameID))
    }

    func localWriteDate(of gameID: UUID) throws -> Date {
        try #require(store.writeDate(gameID: gameID))
    }
}

/// Holds the first upload until the test releases it, so a test can act
/// while that upload is in flight.
actor HeldUploadClient: CloudKitClient {
    let inner: InMemoryCloudKitClient
    private(set) var uploadCalls = 0
    private var held: CheckedContinuation<Void, Never>?
    private var heldArrival: CheckedContinuation<Void, Never>?
    private var isHolding = true

    init(inner: InMemoryCloudKitClient) {
        self.inner = inner
    }

    func upload(gameID: UUID, body: Data, deviceID: String, expecting: UploadExpectation) async throws -> CloudRecord {
        uploadCalls += 1
        if isHolding {
            isHolding = false
            await withCheckedContinuation { continuation in
                held = continuation
                heldArrival?.resume()
                heldArrival = nil
            }
        }
        return try await inner.upload(gameID: gameID, body: body, deviceID: deviceID, expecting: expecting)
    }

    /// Returns once the first upload is being held.
    func waitForHeldUpload() async {
        guard held == nil else { return }
        await withCheckedContinuation { heldArrival = $0 }
    }

    func release() {
        held?.resume()
        held = nil
    }

    func fetchLatest(gameID: UUID) async throws -> CloudRecord? {
        try await inner.fetchLatest(gameID: gameID)
    }

    func listGames() async throws -> [CloudRecordSummary] {
        try await inner.listGames()
    }

    func isAccountAvailable() async -> Bool {
        await inner.isAccountAvailable()
    }
}

func world(seed: UInt64 = 1) -> World {
    World.fixtureWithTerrain(width: 4, height: 4, fill: .grass, seed: seed)
}

func saveBytes(_ world: World) throws -> Data {
    let scratch = SaveStore(baseDirectory: FileManager.default.temporaryDirectory
        .appendingPathComponent("citybuilder-tvsync-scratch-\(UUID().uuidString)"))
    let id = UUID()
    try scratch.save(world, gameID: id)
    return try scratch.writer.read(from: scratch.url(for: id))
}

/// Dates the local save of `gameID` `offset` seconds from its remote record.
func setLocalWriteDate(_ harness: Harness, gameID: UUID, offset: TimeInterval) async throws {
    let remote = try #require(await harness.client.records[gameID]).modificationDate
    try FileManager.default.setAttributes(
        [.modificationDate: remote.addingTimeInterval(offset)],
        ofItemAtPath: harness.store.url(for: gameID).path
    )
}

/// A client whose calls can hang, ignoring cancellation, or run a hook,
/// over an in-memory cloud.
actor ScriptedClient: CloudKitClient {
    let inner: InMemoryCloudKitClient
    var hangsListing = false
    var hangsUploads = false
    var beforeFetch: (@Sendable () -> Void)?
    var hangsAfterUpload = false
    private(set) var fetchCalls = 0
    var beforeUpload: (@Sendable () async -> Void)?
    private let hung = Hang()

    init(inner: InMemoryCloudKitClient) {
        self.inner = inner
    }

    func configure(
        hangsListing: Bool = false,
        hangsUploads: Bool = false,
        hangsAfterUpload: Bool = false,
        beforeFetch: (@Sendable () -> Void)? = nil,
        beforeUpload: (@Sendable () async -> Void)? = nil
    ) {
        self.hangsListing = hangsListing
        self.hangsUploads = hangsUploads
        self.hangsAfterUpload = hangsAfterUpload
        self.beforeFetch = beforeFetch
        self.beforeUpload = beforeUpload
    }

    /// Lets every hung call go on.
    func release() async {
        hangsListing = false
        hangsUploads = false
        hangsAfterUpload = false
        await hung.release()
    }

    private func hang() async {
        await hung.wait()
    }

    func upload(gameID: UUID, body: Data, deviceID: String, expecting: UploadExpectation) async throws -> CloudRecord {
        if hangsUploads { await hang() }
        await beforeUpload?()
        let record = try await inner.upload(gameID: gameID, body: body, deviceID: deviceID, expecting: expecting)
        if hangsAfterUpload { await hang() }
        return record
    }

    func fetchLatest(gameID: UUID) async throws -> CloudRecord? {
        fetchCalls += 1
        beforeFetch?()
        return try await inner.fetchLatest(gameID: gameID)
    }

    func listGames() async throws -> [CloudRecordSummary] {
        if hangsListing { await hang() }
        return try await inner.listGames()
    }

    func isAccountAvailable() async -> Bool {
        await inner.isAccountAvailable()
    }
}

actor Outcome<Value: Sendable> {
    var value: Value?

    func set(_ value: Value) {
        self.value = value
    }
}

/// Runs `operation` and returns its value, or nil if it has not finished
/// within `limit`. A call that never returns is left running.
func finishing<Value: Sendable>(
    within limit: Duration,
    _ operation: @escaping @Sendable () async -> Value
) async -> Value? {
    let outcome = Outcome<Value>()
    Task { await outcome.set(operation()) }
    let deadline = ContinuousClock.now + limit
    while ContinuousClock.now < deadline {
        if let value = await outcome.value { return value }
        try? await Task.sleep(for: .milliseconds(10))
    }
    return await outcome.value
}

/// Holds callers until released, ignoring cancellation.
actor Hang {
    private var held: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        await withCheckedContinuation { held.append($0) }
    }

    func release() {
        held.forEach { $0.resume() }
        held.removeAll()
    }
}

/// Dates the local save of `gameID` `seconds` into the past.
func backdateLocalSave(_ harness: Harness, gameID: UUID, by seconds: TimeInterval = 60) throws {
    try FileManager.default.setAttributes(
        [.modificationDate: Date(timeIntervalSinceNow: -seconds)],
        ofItemAtPath: harness.store.url(for: gameID).path
    )
}
