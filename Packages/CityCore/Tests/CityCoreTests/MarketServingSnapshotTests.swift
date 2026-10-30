import Foundation
import Testing
@testable import CityCore

// Scenarios from openspec/changes/visible-distribution
// (platform-shells / Market lines in the inspector).

/// A grass strip with a road along y = 3 and a town center at (0, 0), whose
/// road side runs to x = 2: a house at (x, 4) sits x - 2 road tiles from it.
private func strip() -> (World, EntityID) {
    var world = World.fixtureWithTerrain(width: 44, height: 9, fill: .grass, seed: 1)
    for x in 0 ... 43 {
        let tile = TileCoordinate(x: x, y: 3)
        SignatureFixture.inject(.road, at: tile, in: &world)
        world.roadGraph.addRoad(at: tile)
    }
    let hub = addOperational(.townCenter, at: TileCoordinate(x: 0, y: 0), in: &world)
    return (world, hub)
}

@Test("the snapshot names the market serving a house and its road distance")
func snapshotNamesTheServingMarket() {
    var (world, hub) = strip()
    let near = addOperational(.house, at: TileCoordinate(x: 10, y: 4), residents: 2, in: &world)
    let serving = world.snapshot().marketServing[near]
    #expect(serving == MarketServing(hub: hub, distance: 8))
}

@Test("a house beyond every market's reach has no serving market in the snapshot")
func snapshotLeavesAnUnservedHouseOut() {
    var (world, _) = strip()
    let far = addOperational(.house, at: TileCoordinate(x: 40, y: 4), residents: 2, in: &world)
    let snapshot = world.snapshot()
    #expect(snapshot.marketServing[far] == nil)
    #expect(snapshot.buildingIssues[far] == .noMarketInReach)
}
