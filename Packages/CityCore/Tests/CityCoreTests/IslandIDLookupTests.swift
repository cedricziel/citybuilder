import Foundation
import Testing
@testable import CityCore

// Tests for `World.islandID(at:)` — the placement-time lookup that
// powers `canPlace`'s per-island material check
// (add-build-materials-cost M7).

@Test("scenario: islandid lookup resolves the containing island")
func scenarioIslandIDLookupResolvesTheContainingIsland() {
    let world = World.newGame(layout: .archipelago, seed: 5)
    for island in world.islands {
        let centerX = (island.bounds.minX + island.bounds.maxX) / 2
        let centerY = (island.bounds.minY + island.bounds.maxY) / 2
        let resolved = world.islandID(at: TileCoordinate(x: centerX, y: centerY))
        #expect(resolved == island.id)
    }
}

@Test("scenario: islandid lookup returns nil for water")
func scenarioIslandIDLookupReturnsNilForWater() {
    let world = World.newGame(layout: .archipelago, seed: 5)
    #expect(world.islandID(at: TileCoordinate(x: 0, y: 0)) == nil)
}

@Test("island lookup follows a water change after a cached lookup")
func islandLookupFollowsAWaterChange() {
    var world = World.fixtureWithTerrain(width: 5, height: 1, fill: .grass, seed: 1)
    #expect(world.islandID(at: TileCoordinate(x: 4, y: 0)) == 1)
    world.terrainGrid[2] = .water
    #expect(world.islandID(at: TileCoordinate(x: 2, y: 0)) == nil)
    #expect(world.islandID(at: TileCoordinate(x: 4, y: 0)) == 2)
    world.terrainGrid[0] = .forest
    #expect(world.islandID(at: TileCoordinate(x: 0, y: 0)) == 1)
}
