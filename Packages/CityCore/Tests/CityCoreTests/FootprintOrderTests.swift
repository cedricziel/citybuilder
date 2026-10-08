import Foundation
import Testing
@testable import CityCore

// Footprint neighbour scans must walk tiles in footprint order, not
// Set order: Swift seeds Set hashing per process, so a Set walk makes
// replays of identical inputs diverge.

@Test("lumberjack clears the first adjacent forest tile in footprint order")
func lumberjackClearsForestInFootprintOrder() {
    var world = World.fixtureWithTerrain(width: 6, height: 6, fill: .forest, seed: 1)
    let anchor = TileCoordinate(x: 2, y: 2)
    world.clearAdjacentForest(anchor: anchor, footprint: Footprint(width: 2, height: 2))
    // Footprint order starts at the anchor (2, 2); its first
    // non-footprint neighbour in +x, -x, +y, -y order is (1, 2).
    #expect(world.terrain(at: TileCoordinate(x: 1, y: 2)) == .grass)
    let cleared = (0 ..< 6).flatMap { y in (0 ..< 6).map { TileCoordinate(x: $0, y: y) } }
        .filter { world.terrain(at: $0) == .grass }
    #expect(cleared.count == 1)
}
