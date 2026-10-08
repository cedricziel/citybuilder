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
    inner.removeValue(forKey: "calendar")
    inner.removeValue(forKey: "culture")
    inner.removeValue(forKey: "age")
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
    inner.removeValue(forKey: "culture")
    inner.removeValue(forKey: "age")
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
    inner.removeValue(forKey: "age")
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
