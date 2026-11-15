import CityCore
import Foundation
import Testing
@testable import CityPersistence

private final class FakeClock: AutosaveClock, @unchecked Sendable {
    private let lock = NSLock()
    private var current = Date(timeIntervalSince1970: 1_000_000)
    func now() -> Date {
        lock.withLock { current }
    }

    func advance(_ seconds: TimeInterval) {
        lock.withLock { current = current.addingTimeInterval(seconds) }
    }
}

/// A writer on the real disk that can fail writes to chosen files and
/// reports how many writes ran at once.
private final class ProbeWriter: FileWriter, @unchecked Sendable {
    private let lock = NSLock()
    private let disk = AtomicDiskWriter()
    private var failing = false
    private var writes = 0
    private var running = 0
    private(set) var maxConcurrent = 0
    var delay: TimeInterval = 0

    var writeCount: Int {
        lock.withLock { writes }
    }

    func failWrites(_ value: Bool) {
        lock.withLock { failing = value }
    }

    func write(_ data: Data, to url: URL) throws {
        let shouldFail: Bool = lock.withLock {
            writes += 1
            running += 1
            maxConcurrent = max(maxConcurrent, running)
            return failing
        }
        defer { lock.withLock { running -= 1 } }
        if delay > 0 { Thread.sleep(forTimeInterval: delay) }
        if shouldFail { throw NSError(domain: "fault", code: 1) }
        try disk.write(data, to: url)
    }

    func read(from url: URL) throws -> Data {
        try disk.read(from: url)
    }

    func remove(at url: URL) throws {
        try disk.remove(at: url)
    }

    func exists(at url: URL) -> Bool {
        disk.exists(at: url)
    }
}

private func tempDirectory() -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent("autosave-tests-\(UUID().uuidString)")
}

private func playedWorld(ticks: Int) -> World {
    var world = World.newGame()
    for _ in 0 ..< ticks {
        _ = world.tick()
    }
    return world
}

private func bankruptWorld() throws -> World {
    let data = try JSONEncoder().encode(playedWorld(ticks: 5))
    var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    var economy = try #require(object["economy"] as? [String: Any])
    economy["gameOver"] = true
    object["economy"] = economy
    return try JSONDecoder().decode(World.self, from: JSONSerialization.data(withJSONObject: object))
}

@MainActor
private final class AutosaveHarness {
    let clock = FakeClock()
    let writer = ProbeWriter()
    let store: SaveStore
    let gameID = UUID()
    var world: World?
    var results: [AutosaveResult] = []
    var coordinator: AutosaveCoordinator!

    init(world: World? = playedWorld(ticks: 5)) {
        store = SaveStore(baseDirectory: tempDirectory(), writer: writer)
        self.world = world
        coordinator = AutosaveCoordinator(
            store: store, gameID: gameID, clock: clock, interval: 300,
            worldProvider: { [unowned self] in self.world },
            onResult: { [unowned self] in results.append($0) }
        )
    }

    func play(_ ticks: Int) {
        guard var current = world else { return }
        for _ in 0 ..< ticks {
            _ = current.tick()
        }
        world = current
    }
}

@MainActor
@Suite("Autosave")
struct AutosaveTests {
    @Test("a season change saves the played town into the slot")
    func seasonChangeSaves() async throws {
        let harness = AutosaveHarness()
        harness.coordinator.request(.seasonChange)
        await harness.coordinator.waitUntilIdle()
        #expect(harness.results.count == 1)
        #expect(try harness.store.load(gameID: harness.gameID).tickCount == 5)
    }

    @Test("the interval saves after five minutes and not before")
    func intervalTrigger() async {
        let harness = AutosaveHarness()
        harness.clock.advance(299)
        harness.coordinator.playStepped()
        await harness.coordinator.waitUntilIdle()
        #expect(harness.writer.writeCount == 0)
        harness.clock.advance(1)
        harness.coordinator.playStepped()
        await harness.coordinator.waitUntilIdle()
        #expect(harness.writer.writeCount == 1)
        // The next interval starts from that save.
        harness.play(3)
        harness.clock.advance(100)
        harness.coordinator.playStepped()
        await harness.coordinator.waitUntilIdle()
        #expect(harness.writer.writeCount == 1)
    }

    @Test("triggers during a write coalesce into one more write, never concurrent")
    func coalescing() async throws {
        let harness = AutosaveHarness()
        harness.writer.delay = 0.05
        harness.coordinator.request(.seasonChange)
        harness.play(2)
        harness.coordinator.request(.seasonChange)
        harness.coordinator.request(.interval)
        harness.coordinator.request(.seasonChange)
        await harness.coordinator.waitUntilIdle()
        // The first save writes the file; the one coalesced save writes the backup and the file.
        #expect(harness.writer.writeCount == 3)
        #expect(harness.results.count == 2)
        #expect(harness.writer.maxConcurrent == 1)
        #expect(try harness.store.load(gameID: harness.gameID).tickCount == 7)
    }

    @Test("leaving the foreground has written before it returns")
    func leavingForegroundWritesNow() throws {
        let harness = AutosaveHarness()
        harness.coordinator.request(.leavingForeground)
        #expect(try harness.store.load(gameID: harness.gameID).tickCount == 5)
        #expect(harness.results.count == 1)
    }

    @Test("a town unchanged since the last save is not written again")
    func unchangedTownSkipped() async {
        let harness = AutosaveHarness()
        harness.coordinator.request(.leavingForeground)
        harness.coordinator.request(.leavingForeground)
        harness.coordinator.request(.seasonChange)
        await harness.coordinator.waitUntilIdle()
        #expect(harness.writer.writeCount == 1)
    }

    @Test("no autosave for a town not yet played, a bankrupt town or a lost scenario")
    func finishedOrFreshGamesSkipped() async throws {
        let fresh = AutosaveHarness(world: World.newGame())
        fresh.coordinator.request(.leavingForeground)
        #expect(fresh.writer.writeCount == 0)

        let bankrupt = try bankruptWorld()
        #expect(!AutosavePolicy.allows(bankrupt))
        let broke = AutosaveHarness(world: bankrupt)
        broke.coordinator.request(.leavingForeground)
        broke.coordinator.request(.seasonChange)
        await broke.coordinator.waitUntilIdle()
        #expect(broke.writer.writeCount == 0)
        #expect(!broke.store.exists(gameID: broke.gameID))

        let none = AutosaveHarness(world: nil)
        none.coordinator.request(.leavingForeground)
        #expect(none.writer.writeCount == 0)
    }

    @Test("a stopped coordinator saves nothing")
    func stopped() async {
        let harness = AutosaveHarness()
        harness.coordinator.stop()
        harness.coordinator.request(.leavingForeground)
        harness.coordinator.request(.seasonChange)
        await harness.coordinator.waitUntilIdle()
        #expect(harness.writer.writeCount == 0)
    }

    @Test("a failed save keeps the previous file and reports it")
    func failedSaveKeepsPreviousFile() async throws {
        let harness = AutosaveHarness()
        harness.coordinator.request(.leavingForeground)
        let before = try harness.writer.read(from: harness.store.url(for: harness.gameID))
        harness.play(4)
        harness.writer.failWrites(true)
        harness.coordinator.request(.seasonChange)
        await harness.coordinator.waitUntilIdle()
        guard case .failed = harness.results.last else {
            Issue.record("expected a failure report")
            return
        }
        #expect(try harness.writer.read(from: harness.store.url(for: harness.gameID)) == before)
        // The next trigger tries again.
        harness.writer.failWrites(false)
        harness.coordinator.request(.seasonChange)
        await harness.coordinator.waitUntilIdle()
        #expect(try harness.store.load(gameID: harness.gameID).tickCount == 9)
    }

    @Test("the previous autosave becomes the single backup")
    func backupKeepsPreviousAutosave() throws {
        let harness = AutosaveHarness()
        harness.coordinator.request(.leavingForeground)
        harness.play(5)
        harness.coordinator.request(.leavingForeground)
        harness.play(5)
        harness.coordinator.request(.leavingForeground)
        let backup = try harness.store.decode(harness.writer.read(from: harness.store.backupURL(for: harness.gameID)))
        #expect(backup.tickCount == 10)
        #expect(try harness.store.load(gameID: harness.gameID).tickCount == 15)
    }

    @Test("a corrupt main file loads from the backup")
    func corruptMainFallsBackToBackup() throws {
        let harness = AutosaveHarness()
        harness.coordinator.request(.leavingForeground)
        harness.play(5)
        harness.coordinator.request(.leavingForeground)
        try Data("not json".utf8).write(to: harness.store.url(for: harness.gameID))
        #expect(try harness.store.load(gameID: harness.gameID).tickCount == 5)
    }

    @Test("a corrupt main file never replaces a good backup")
    func corruptMainKeepsBackup() throws {
        let harness = AutosaveHarness()
        harness.coordinator.request(.leavingForeground)
        harness.play(5)
        harness.coordinator.request(.leavingForeground)
        try Data("not json".utf8).write(to: harness.store.url(for: harness.gameID))
        harness.play(5)
        harness.coordinator.request(.leavingForeground)
        #expect(try harness.store.decode(harness.writer.read(from: harness.store.backupURL(for: harness.gameID))).tickCount == 5)
        #expect(try harness.store.load(gameID: harness.gameID).tickCount == 15)
    }

    @Test("a corrupt main file without a backup still fails to load")
    func corruptWithoutBackupFails() throws {
        let harness = AutosaveHarness()
        try FileManager.default.createDirectory(at: harness.store.baseDirectory, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: harness.store.url(for: harness.gameID))
        #expect(throws: SaveError.self) { try harness.store.load(gameID: harness.gameID) }
    }

    @Test("the disk writer leaves the old file when the write fails")
    func atomicWriteKeepsOldFile() throws {
        let dir = tempDirectory()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let target = dir.appendingPathComponent("slot.json")
        let writer = AtomicDiskWriter()
        try writer.write(Data("old".utf8), to: target)
        // A directory squatting on the temporary path makes the write fail.
        try FileManager.default.createDirectory(
            at: target.appendingPathExtension("tmp"), withIntermediateDirectories: false
        )
        #expect(throws: (any Error).self) { try writer.write(Data("new".utf8), to: target) }
        #expect(try Data(contentsOf: target) == Data("old".utf8))
    }

    @Test("the disk writer replaces an existing file")
    func atomicWriteReplaces() throws {
        let dir = tempDirectory()
        let target = dir.appendingPathComponent("slot.json")
        let writer = AtomicDiskWriter()
        try writer.write(Data("old".utf8), to: target)
        try writer.write(Data("new".utf8), to: target)
        #expect(try Data(contentsOf: target) == Data("new".utf8))
        #expect(!FileManager.default.fileExists(atPath: target.appendingPathExtension("tmp").path))
    }

    @Test("the backup is not listed as a save")
    func backupNotListed() throws {
        let harness = AutosaveHarness()
        harness.coordinator.request(.leavingForeground)
        harness.play(5)
        harness.coordinator.request(.leavingForeground)
        #expect(try harness.store.listSaves().map(\.gameID) == [harness.gameID])
    }
}
