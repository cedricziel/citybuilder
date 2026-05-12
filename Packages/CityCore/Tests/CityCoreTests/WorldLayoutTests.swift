import Foundation
import Testing
@testable import CityCore

// Tests for the M6 world-terrain modifications + island metadata
// + climate band of add-archipelago-and-sea.

// MARK: - World layout

@Test("scenario: single-island layout deterministic per seed")
func scenarioSingleIslandLayoutDeterministicPerSeed() {
    let one = World.newGame(layout: .singleIsland, seed: 42)
    let two = World.newGame(layout: .singleIsland, seed: 42)
    #expect(one.terrainGrid == two.terrainGrid)
    #expect(one.layout == .singleIsland)
    #expect(two.layout == .singleIsland)
}

@Test("scenario: archipelago layout deterministic per seed")
func scenarioArchipelagoLayoutDeterministicPerSeed() {
    let one = World.newGame(layout: .archipelago, seed: 42)
    let two = World.newGame(layout: .archipelago, seed: 42)
    #expect(one.terrainGrid == two.terrainGrid)
    #expect(one.layout == .archipelago)
    #expect(two.layout == .archipelago)
}

@Test("scenario: different layouts diverge under the same seed")
func scenarioDifferentLayoutsDivergeUnderTheSameSeed() {
    let island = World.newGame(layout: .singleIsland, seed: 7)
    let archipelago = World.newGame(layout: .archipelago, seed: 7)
    #expect(island.terrainGrid != archipelago.terrainGrid)
}

@Test("scenario: layout choice persists across save/load")
func scenarioLayoutChoicePersistsAcrossSaveLoad() throws {
    let world = World.newGame(layout: .archipelago, seed: 99)
    let data = try JSONEncoder().encode(world)
    let loaded = try JSONDecoder().decode(World.self, from: data)
    #expect(loaded.layout == .archipelago)
}

// MARK: - Island metadata

@Test("scenario: single-island layout produces exactly one island")
func scenarioSingleIslandLayoutProducesExactlyOneIsland() {
    let world = World.newGame(layout: .singleIsland, seed: 1)
    #expect(world.islands.count == 1)
    let buildable = world.terrainGrid.count { kind in
        kind == .grass || kind == .forest || kind == .beach || kind == .mountain
    }
    #expect(world.islands[0].tileCount == buildable)
}

@Test("scenario: archipelago layout produces multiple islands")
func scenarioArchipelagoLayoutProducesMultipleIslands() {
    let world = World.newGame(layout: .archipelago, seed: 3)
    #expect(world.islands.count >= 2)
    for island in world.islands {
        #expect(island.tileCount > 0)
    }
}

@Test("scenario: islandid stable across save/load")
func scenarioIslandIDStableAcrossSaveLoad() throws {
    let world = World.newGame(layout: .archipelago, seed: 17)
    let data = try JSONEncoder().encode(world)
    let loaded = try JSONDecoder().decode(World.self, from: data)
    let originalIDs = world.islands.map(\.id)
    let loadedIDs = loaded.islands.map(\.id)
    #expect(originalIDs == loadedIDs)
}

// MARK: - Climate band

@Test("scenario: every island has a climate")
func scenarioEveryIslandHasAClimate() {
    let world = World.newGame(layout: .archipelago, seed: 5)
    for island in world.islands {
        #expect(island.climate == .temperate || island.climate == .tropical)
    }
}

@Test("scenario: climate persists across save/load")
func scenarioClimatePersistsAcrossSaveLoad() throws {
    let world = World.newGame(layout: .archipelago, seed: 5)
    let data = try JSONEncoder().encode(world)
    let loaded = try JSONDecoder().decode(World.self, from: data)
    for (original, restored) in zip(world.islands, loaded.islands) {
        #expect(original.climate == restored.climate)
    }
}
