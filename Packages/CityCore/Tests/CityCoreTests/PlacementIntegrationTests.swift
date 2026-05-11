import Foundation
import Testing
@testable import CityCore

/// Integration test for M2 task 3.8: place a building through the command
/// queue, tick, then verify the resulting snapshot shows occupancy.
@Test("place command flows through queue and lands on next tick")
func placeCommandFlowsThroughQueue() {
    var world = World.fixtureWithTerrain(width: 8, height: 8, fill: .grass, seed: 1)
    let target = TileCoordinate(x: 4, y: 4)

    // Before: tile is empty.
    #expect(world.snapshot().occupiedTiles[target] == nil)

    world.enqueue(.place(.house, at: target))
    // Mid-tick: not yet applied.
    #expect(world.snapshot().occupiedTiles[target] == nil)

    world.tick()
    // After: snapshot reflects occupancy.
    let snap = world.snapshot()
    let occupant = snap.occupiedTiles[target]
    #expect(occupant != nil)
    #expect(occupant?.raw == 1, "first placed building gets raw=1")
}

@Test("place command on water is rejected")
func placeCommandOnWaterIsRejected() {
    var world = World.fixtureWithTerrain(width: 4, height: 4, fill: .water, seed: 1)
    let target = TileCoordinate(x: 1, y: 1)
    world.enqueue(.place(.house, at: target))
    world.tick()
    #expect(world.snapshot().occupiedTiles[target] == nil, "water rejection drops the placement")
}

@Test("placing twice on the same tile rejects the second")
func placingTwiceOnSameTileRejectsSecond() {
    var world = World.fixtureWithTerrain(width: 4, height: 4, fill: .grass, seed: 1)
    let target = TileCoordinate(x: 2, y: 2)
    world.enqueue(.place(.house, at: target))
    world.tick()
    let firstId = world.snapshot().occupiedTiles[target]
    world.enqueue(.place(.warehouse, at: target))
    world.tick()
    let secondId = world.snapshot().occupiedTiles[target]
    #expect(firstId == secondId, "second placement must not overwrite the first")
}
