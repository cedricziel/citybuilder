import Foundation
import Testing
@testable import CityCore

// Scenarios from openspec/changes/fix-playable-foundation/specs/rendering-2_5d
// (Requirement: Road-access marker).

private func houseWorld() throws -> (World, EntityID) {
    var world = World.fixtureWithTerrain(width: 8, height: 8, fill: .grass, seed: 1)
    world.enqueue(.place(.house, at: TileCoordinate(x: 2, y: 2)))
    world.tick()
    return try (world, #require(world.occupiedTiles[TileCoordinate(x: 2, y: 2)]))
}

@Test("scenario: snapshot lists a building without an adjacent road")
func scenarioSnapshotListsABuildingWithoutAnAdjacentRoad() throws {
    let (world, house) = try houseWorld()
    #expect(world.snapshot().roadDisconnectedBuildings.contains(house))
}

@Test("scenario: a touching road clears the snapshot entry")
func scenarioATouchingRoadClearsTheSnapshotEntry() throws {
    var (world, house) = try houseWorld()
    world.enqueue(.place(.road, at: TileCoordinate(x: 1, y: 2)))
    world.tick()
    #expect(!world.snapshot().roadDisconnectedBuildings.contains(house))
}

@Test("a diagonal road does not count as access")
func diagonalRoadDoesNotCount() throws {
    var (world, house) = try houseWorld()
    world.enqueue(.place(.road, at: TileCoordinate(x: 1, y: 1)))
    world.tick()
    #expect(world.snapshot().roadDisconnectedBuildings.contains(house))
}

@Test("roads never appear as road-disconnected")
func roadsAreNeverListed() {
    var world = World.fixtureWithTerrain(width: 8, height: 8, fill: .grass, seed: 1)
    world.enqueue(.place(.road, at: TileCoordinate(x: 4, y: 4)))
    world.tick()
    #expect(world.snapshot().roadDisconnectedBuildings.isEmpty)
}
