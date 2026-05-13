import CityCore
import Foundation
import Testing
@testable import CityPersistence

// MARK: - Helpers

private func tempDir() -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("citybuilder-meta-\(UUID().uuidString)")
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func touchSave(in store: SaveStore, gameID: UUID, at date: Date) throws {
    let world = World.fixtureWithTerrain(width: 2, height: 2, fill: .grass, seed: 0)
    try store.save(world, gameID: gameID)
    try FileManager.default.setAttributes(
        [.modificationDate: date],
        ofItemAtPath: store.url(for: gameID).path
    )
}

// MARK: - Save metadata query

@Test("scenario: empty store returns nil")
func scenarioMostRecentEmptyStoreReturnsNil() throws {
    let store = SaveStore(baseDirectory: tempDir())
    #expect(try store.mostRecentSave() == nil)
}

@Test("scenario: single save returns that save")
func scenarioMostRecentSingleSave() throws {
    let store = SaveStore(baseDirectory: tempDir())
    let gameID = UUID()
    let date = Date(timeIntervalSinceReferenceDate: 1000)
    try touchSave(in: store, gameID: gameID, at: date)

    let meta = try #require(try store.mostRecentSave())
    #expect(meta.gameID == gameID)
    #expect(meta.writeDate == date)
}

@Test("scenario: multiple saves return the newest")
func scenarioMostRecentMultipleSaves() throws {
    let store = SaveStore(baseDirectory: tempDir())
    let oldID = UUID()
    let midID = UUID()
    let newID = UUID()
    try touchSave(in: store, gameID: oldID, at: Date(timeIntervalSinceReferenceDate: 100))
    try touchSave(in: store, gameID: midID, at: Date(timeIntervalSinceReferenceDate: 200))
    try touchSave(in: store, gameID: newID, at: Date(timeIntervalSinceReferenceDate: 300))

    let meta = try #require(try store.mostRecentSave())
    #expect(meta.gameID == newID)
    #expect(meta.writeDate == Date(timeIntervalSinceReferenceDate: 300))
}

@Test("scenario: query does not decode world")
func scenarioMostRecentSkipsDecode() throws {
    let dir = tempDir()
    let store = SaveStore(baseDirectory: dir)
    let gameID = UUID()
    let url = store.url(for: gameID)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    try Data("not json".utf8).write(to: url)
    let date = Date(timeIntervalSinceReferenceDate: 555)
    try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: url.path)

    let meta = try #require(try store.mostRecentSave())
    #expect(meta.gameID == gameID)
    #expect(meta.writeDate == date)
}

// MARK: - Save listing query

@Test("scenario: listing reflects sort order")
func scenarioListSavesSortedDescending() throws {
    let store = SaveStore(baseDirectory: tempDir())
    let oldID = UUID()
    let midID = UUID()
    let newID = UUID()
    try touchSave(in: store, gameID: oldID, at: Date(timeIntervalSinceReferenceDate: 100))
    try touchSave(in: store, gameID: midID, at: Date(timeIntervalSinceReferenceDate: 200))
    try touchSave(in: store, gameID: newID, at: Date(timeIntervalSinceReferenceDate: 300))

    let list = try store.listSaves()
    #expect(list.map(\.gameID) == [newID, midID, oldID])
}

@Test("scenario: empty store returns empty list")
func scenarioListSavesEmpty() throws {
    let store = SaveStore(baseDirectory: tempDir())
    #expect(try store.listSaves().isEmpty)
}

@Test("scenario: listing tolerates non-save files")
func scenarioListSavesIgnoresForeignFiles() throws {
    let dir = tempDir()
    let store = SaveStore(baseDirectory: dir)
    let gameID = UUID()
    try touchSave(in: store, gameID: gameID, at: Date(timeIntervalSinceReferenceDate: 42))

    // Foreign files in the same dir must be skipped.
    try Data("hi".utf8).write(to: dir.appendingPathComponent("README.txt"))
    try Data("hi".utf8).write(to: dir.appendingPathComponent("not-a-uuid.json"))

    let list = try store.listSaves()
    #expect(list.map(\.gameID) == [gameID])
}
