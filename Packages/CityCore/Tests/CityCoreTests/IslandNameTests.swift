import Foundation
import Testing
@testable import CityCore

// Tests for the Island.name metadata added by `add-island-hud-overlay`.
// Each `#### Scenario:` heading under `Requirement: Island name metadata`
// in openspec/changes/add-island-hud-overlay/specs/world-terrain/spec.md
// maps to a `@Test("scenario: ...")` here.

@Test("scenario: island name is deterministic per seed")
func scenarioIslandNameIsDeterministicPerSeed() {
    let one = World.newGame(layout: .archipelago, seed: 42)
    let two = World.newGame(layout: .archipelago, seed: 42)
    let oneNames = one.islands.map(\.name)
    let twoNames = two.islands.map(\.name)
    #expect(oneNames == twoNames)
    #expect(oneNames.allSatisfy { !$0.isEmpty })
}

@Test("scenario: same name persists across save/load")
func scenarioSameNamePersistsAcrossSaveLoad() throws {
    let world = World.newGame(layout: .archipelago, seed: 99)
    let data = try JSONEncoder().encode(world)
    let loaded = try JSONDecoder().decode(World.self, from: data)
    let original = world.islands.map(\.name)
    let restored = loaded.islands.map(\.name)
    #expect(original == restored)
    #expect(restored.allSatisfy { !$0.isEmpty })
}

@Test("scenario: different seeds yield different name distributions")
func scenarioDifferentSeedsYieldDifferentNameDistributions() {
    let alpha = World.newGame(layout: .archipelago, seed: 11)
    let beta = World.newGame(layout: .archipelago, seed: 12)
    let aNames = alpha.islands.map(\.name)
    let bNames = beta.islands.map(\.name)
    // With 64-entry table and ≥2 islands, collision probability is
    // negligible. The lists must not be element-wise identical.
    #expect(aNames != bNames)
}

@Test("scenario: single-island world has a single name")
func scenarioSingleIslandWorldHasASingleName() {
    let world = World.newGame(layout: .singleIsland, seed: 7)
    #expect(world.islands.count == 1)
    let name = world.islands[0].name
    #expect(!name.isEmpty)
    // Determinism for single-island: same seed → same name.
    let other = World.newGame(layout: .singleIsland, seed: 7)
    #expect(other.islands[0].name == name)
}

@Test("scenario: name table covers exactly 64 entries")
func scenarioNameTableCoversExactly64Entries() {
    #expect(IslandNameTable.entries.count == 64)
    // Every entry non-empty and unique.
    #expect(Set(IslandNameTable.entries).count == 64)
}
