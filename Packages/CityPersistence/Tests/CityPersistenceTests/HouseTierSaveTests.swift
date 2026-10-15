import CityCore
import Foundation
import Testing
@testable import CityPersistence

// `tier-needs-data` generates `HouseTier` from the packs. Saves store a
// tier as its raw value (1, 2, 3 before the change), so a save written
// before it must keep every house's tier.

private func v8FixtureURL() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures/saves/v8_archipelago.json")
}

@Test func houseTiersInAnOlderSaveKeepTheirTier() throws {
    var json = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: v8FixtureURL())) as? [String: Any])
    var world = try #require(json["world"] as? [String: Any])
    // Populations as the hand-written `HouseTier` encoded them.
    world["populations"] = [
        ["raw": 9001], ["population": 4, "tier": 1],
        ["raw": 9002], ["population": 6, "tier": 2],
        ["raw": 9003], ["population": 8, "tier": 3]
    ]
    json["world"] = world
    let data = try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys])

    let loaded = try SaveStore(baseDirectory: FileManager.default.temporaryDirectory).decode(data)
    #expect(loaded.populations[EntityID(raw: 9001)]?.tier == .peasants)
    #expect(loaded.populations[EntityID(raw: 9002)]?.tier == .citizens)
    #expect(loaded.populations[EntityID(raw: 9003)]?.tier == .merchants)
    #expect(try JSONEncoder().encode([HouseTier.peasants, .citizens, .merchants]) == Data("[1,2,3]".utf8))
}
