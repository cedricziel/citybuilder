import Foundation
import Testing
@testable import CityCore
@testable import CityPersistence

// population-and-needs / Saves from before market porters keep their houses
// supplied (openspec/changes/visible-distribution, design D6).

private func v12FixtureURL() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures/saves/v12_houses_before_porters.json")
}

/// A new single-island game with four houses whose needs are met, as a v12
/// save: no house stock and no porters, the shape before market porters.
private func makeV12Payload() throws -> Data {
    var world = World.newGame(layout: .singleIsland, seed: 0, difficulty: .normal, rivals: false)
    for (index, tier) in [HouseTier.peasants, .peasants, .citizens, .citizens].enumerated() {
        let id = EntityID(raw: 9000 + UInt32(index))
        world.buildings[id] = Building(id: id, kind: .house, anchor: TileCoordinate(x: index * 3, y: 0), state: .operational)
        var pop = HousePopulation()
        pop.tier = tier
        pop.population = tier.capacity
        for good in tier.needs(in: world.culture) {
            pop.setSatisfied(good, true)
        }
        world.populations[id] = pop
    }
    let data = try JSONEncoder().encode(SaveFile(world: world, writtenAt: fixtureWrittenAt))
    var json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    var inner = json["world"] as? [String: Any] ?? [:]
    inner.removeValue(forKey: "porters")
    let populations = inner["populations"] as? [Any] ?? []
    inner["populations"] = populations.map { entry in
        (entry as? [String: Any]).map { $0.filter { $0.key != "stock" } } ?? entry
    }
    json["world"] = inner
    json["version"] = 12
    return try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys])
}

@Test("fixture: regenerate v12 houses-before-porters save", .enabled(if: regenerateFixtures))
func regenerateV12HousesBeforePortersFixture() throws {
    try requireDeterministicHashing()
    var data = try makeV12Payload()
    data.append(0x0A)
    try data.write(to: v12FixtureURL())
}

@Test("scenario: Loading an older save seeds house stock")
func scenarioAnOlderSavesHousesAreNotShortAfterLoading() throws {
    let data = try Data(contentsOf: v12FixtureURL())
    let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    #expect(parsed["version"] as? Int == 12, "fixture must be a save from before market porters")
    var world = try SaveStore(baseDirectory: FileManager.default.temporaryDirectory).decode(data)
    let houses = world.populations.keys.filter { world.buildings[$0]?.kind == .house }
    #expect(houses.count == 4)
    for id in houses {
        #expect(world.populations[id]?.stock(of: .food) ?? 0 > 0)
    }
    let interval = HousePopulation.consumptionIntervalTicks
    for _ in 0 ... interval - world.tickCount % interval {
        _ = world.tick()
    }
    for id in houses {
        let pop = try #require(world.populations[id])
        #expect(pop.tier.needs(in: world.culture).allSatisfy { !pop.isShort($0) })
    }
}
