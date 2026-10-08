import CityCore
import Foundation
import Testing
@testable import CityPersistence

// Fixture tests for the migrations after v3: calendar (v4 → v5),
// cultures (v5 → v6) and ages (v6 → v7).

private func decodeWorld(_ data: Data) throws -> World {
    try SaveStore(baseDirectory: FileManager.default.temporaryDirectory).decode(data)
}

private func v4FixtureURL() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures/saves/v4_single_island.json")
}

/// Encode a World as a v4 save: the current shape minus `calendar`.
private func makeV4Payload(world: World, writtenAt: Date = Date()) throws -> Data {
    let data = try JSONEncoder().encode(SaveFile(world: world, writtenAt: writtenAt))
    var json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    json["version"] = 4
    var inner = json["world"] as? [String: Any] ?? [:]
    stripKeysNewerThanV8(&inner)
    inner.removeValue(forKey: "calendar")
    inner.removeValue(forKey: "culture")
    inner.removeValue(forKey: "age")
    for key in ["difficulty", "goals", "scenarioWon"] {
        inner.removeValue(forKey: key)
    }
    json["world"] = inner
    return try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys])
}

@Test("fixture: regenerate v4 single-island save", .enabled(if: regenerateFixtures))
func regenerateV4SingleIslandFixture() throws {
    try requireDeterministicHashing()
    // A v4 save predates `add-calendar-and-events`: no `calendar` on World.
    var data = try makeV4Payload(world: World.newGame(), writtenAt: fixtureWrittenAt)
    data.append(0x0A)
    try data.write(to: v4FixtureURL())
}

@Test("scenario: v4 save loads with a calendar")
func scenarioV4SaveLoadsWithACalendar() throws {
    let data = try Data(contentsOf: v4FixtureURL())
    let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    #expect(parsed["version"] as? Int == 4, "fixture must be a v4 save")
    let loaded = try decodeWorld(data)
    #expect(loaded.calendar == CalendarState(startYear: 1200, isActive: true))
}

private func v5FixtureURL() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures/saves/v5_single_island.json")
}

/// Encode a World as a v5 save: the current shape minus `culture`.
private func makeV5Payload(world: World, writtenAt: Date = Date()) throws -> Data {
    let data = try JSONEncoder().encode(SaveFile(world: world, writtenAt: writtenAt))
    var json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    json["version"] = 5
    var inner = json["world"] as? [String: Any] ?? [:]
    stripKeysNewerThanV8(&inner)
    inner.removeValue(forKey: "culture")
    inner.removeValue(forKey: "age")
    for key in ["difficulty", "goals", "scenarioWon"] {
        inner.removeValue(forKey: key)
    }
    json["world"] = inner
    return try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys])
}

@Test("fixture: regenerate v5 single-island save", .enabled(if: regenerateFixtures))
func regenerateV5SingleIslandFixture() throws {
    try requireDeterministicHashing()
    // A v5 save predates `add-cultures`: no `culture` on World.
    var data = try makeV5Payload(world: World.newGame(), writtenAt: fixtureWrittenAt)
    data.append(0x0A)
    try data.write(to: v5FixtureURL())
}

@Test("scenario: v5 save loads as northern european")
func scenarioV5SaveLoadsAsNorthernEuropean() throws {
    let data = try Data(contentsOf: v5FixtureURL())
    let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    #expect(parsed["version"] as? Int == 5, "fixture must be a v5 save")
    let loaded = try decodeWorld(data)
    #expect(loaded.culture == .northernEuropean)
}

private func v6FixtureURL() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures/saves/v6_single_island.json")
}

/// Encode a World as a v6 save: the current shape minus `age`, and
/// without the era techs v6 had no notion of.
private func makeV6Payload(world: World, writtenAt: Date = Date()) throws -> Data {
    let data = try JSONEncoder().encode(SaveFile(world: world, writtenAt: writtenAt))
    var json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    json["version"] = 6
    var inner = json["world"] as? [String: Any] ?? [:]
    stripKeysNewerThanV8(&inner)
    inner.removeValue(forKey: "age")
    for key in ["difficulty", "goals", "scenarioWon"] {
        inner.removeValue(forKey: key)
    }
    if var research = inner["research"] as? [String: Any] {
        let eraTechs: Set = ["feudal-order", "printing-press", "steam-power", "electricity"]
        research["researched"] = (research["researched"] as? [String] ?? []).filter { !eraTechs.contains($0) }
        inner["research"] = research
    }
    json["world"] = inner
    return try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys])
}

@Test("fixture: regenerate v6 single-island save", .enabled(if: regenerateFixtures))
func regenerateV6SingleIslandFixture() throws {
    try requireDeterministicHashing()
    // A v6 save predates `add-historical-ages`: no `age` on World.
    var data = try makeV6Payload(world: World.newGame(), writtenAt: fixtureWrittenAt)
    data.append(0x0A)
    try data.write(to: v6FixtureURL())
}

@Test("scenario: v6 save loads in the medieval age")
func scenarioV6SaveLoadsInTheMedievalAge() throws {
    let data = try Data(contentsOf: v6FixtureURL())
    let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    #expect(parsed["version"] as? Int == 6, "fixture must be a v6 save")
    let loaded = try decodeWorld(data)
    #expect(loaded.age == .medieval)
    #expect(loaded.research.isResearched(.feudalOrder))
}

private func v7FixtureURL() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures/saves/v7_single_island.json")
}

/// Encode a World as a v7 save: the current shape minus difficulty and goals.
private func makeV7Payload(world: World, writtenAt: Date = Date()) throws -> Data {
    let data = try JSONEncoder().encode(SaveFile(world: world, writtenAt: writtenAt))
    var json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    json["version"] = 7
    var inner = json["world"] as? [String: Any] ?? [:]
    stripKeysNewerThanV8(&inner)
    for key in ["difficulty", "goals", "scenarioWon"] {
        inner.removeValue(forKey: key)
    }
    json["world"] = inner
    return try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys])
}

@Test("fixture: regenerate v7 single-island save", .enabled(if: regenerateFixtures))
func regenerateV7SingleIslandFixture() throws {
    try requireDeterministicHashing()
    // A v7 save predates `add-difficulty-and-goals`.
    var data = try makeV7Payload(world: World.newGame(), writtenAt: fixtureWrittenAt)
    data.append(0x0A)
    try data.write(to: v7FixtureURL())
}

@Test("scenario: v7 save loads as a normal sandbox")
func scenarioV7SaveLoadsAsANormalSandbox() throws {
    let data = try Data(contentsOf: v7FixtureURL())
    let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    #expect(parsed["version"] as? Int == 7, "fixture must be a v7 save")
    let loaded = try decodeWorld(data)
    #expect(loaded.difficulty == .normal)
    #expect(loaded.goals.isEmpty)
    #expect(!loaded.scenarioWon)
}

private func v8FixtureURL() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures/saves/v8_archipelago.json")
}

/// Encode a World as a v8 save: the current shape minus rivals and owners.
private func makeV8Payload(world: World, writtenAt: Date = Date()) throws -> Data {
    let data = try JSONEncoder().encode(SaveFile(world: world, writtenAt: writtenAt))
    var json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    json["version"] = 8
    var inner = json["world"] as? [String: Any] ?? [:]
    stripKeysNewerThanV8(&inner)
    json["world"] = inner
    return try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys])
}

@Test("fixture: regenerate v8 archipelago save", .enabled(if: regenerateFixtures))
func regenerateV8ArchipelagoFixture() throws {
    try requireDeterministicHashing()
    // A v8 save predates `add-rival-towns`: no rivals, no owners.
    let world = World.newGame(layout: .archipelago, seed: 0, difficulty: .normal, rivals: false)
    var data = try makeV8Payload(world: world, writtenAt: fixtureWrittenAt)
    data.append(0x0A)
    try data.write(to: v8FixtureURL())
}

@Test("scenario: v8 save loads without rivals")
func scenarioV8SaveLoadsWithoutRivals() throws {
    let data = try Data(contentsOf: v8FixtureURL())
    let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    #expect(parsed["version"] as? Int == 8, "fixture must be a v8 save")
    let migrated = try MigrationRegistry().migrate(payload: data, toVersion: SaveFile.currentVersion)
    let migratedJSON = try JSONSerialization.jsonObject(with: migrated) as? [String: Any] ?? [:]
    #expect(migratedJSON["version"] as? Int == 9)
    let loaded = try decodeWorld(data)
    #expect(loaded.layout == .archipelago)
    #expect(loaded.rivals.isEmpty)
    #expect(!loaded.buildings.isEmpty)
    #expect(loaded.buildings.values.allSatisfy { $0.owner == .player })
    #expect(loaded.ships.values.allSatisfy { $0.owner == .player })
    #expect(loaded.islands.allSatisfy { loaded.owner(ofIsland: $0.id) == .player })
}
