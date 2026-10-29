import CityCore
import Foundation
import Testing
@testable import CityPersistence

// persistence-save-load / Saves carry house shortage counts
// (openspec/changes/decline-grace).

private func v8FixtureURL() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures/saves/v8_archipelago.json")
}

@Test("scenario: shortage counts survive a save")
func scenarioShortageCountsSurviveASave() throws {
    var house = HousePopulation()
    house.tier = .merchants
    house.population = 8
    house.recordConsumption(of: .tools, short: true)
    house.recordConsumption(of: .tools, short: true)
    house.recordConsumption(of: .bread, short: true)
    let loaded = try JSONDecoder().decode(HousePopulation.self, from: JSONEncoder().encode(house))
    #expect(loaded.shortIntervals(of: .tools) == 2)
    #expect(loaded.shortIntervals(of: .bread) == 1)
    #expect(loaded.shortIntervals(of: .food) == 0)
    #expect(loaded == house)
}

@Test("scenario: an older save starts its grace on load")
func scenarioAnOlderSaveStartsItsGraceOnLoad() throws {
    var json = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: v8FixtureURL())) as? [String: Any])
    var world = try #require(json["world"] as? [String: Any])
    // A house saved before shortage counts: short of bread, with no counts.
    world["populations"] = [
        ["raw": 9001], ["population": 8, "tier": 3, "shortGoods": ["bread"]]
    ]
    json["world"] = world
    let data = try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys])

    let loaded = try SaveStore(baseDirectory: FileManager.default.temporaryDirectory).decode(data)
    let house = try #require(loaded.populations[EntityID(raw: 9001)])
    #expect(house.shortIntervals(of: .bread) == 1)
    #expect(Good.allCases.filter { house.shortIntervals(of: $0) > 0 } == [.bread])
}
