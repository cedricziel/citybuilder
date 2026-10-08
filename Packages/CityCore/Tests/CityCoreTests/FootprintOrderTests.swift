import Foundation
import Testing
@testable import CityCore

// Footprint neighbour scans must walk tiles in footprint order, not
// Set order: Swift seeds Set hashing per process, so a Set walk makes
// replays of identical inputs diverge.

@Test("lumberjack picks the first catchment forest tile in row-major order")
func lumberjackPicksForestInRowMajorOrder() {
    let world = World.fixtureWithTerrain(width: 8, height: 8, fill: .forest, seed: 1)
    // The 2-tile catchment of a 2×2 at (3, 3) starts at (1, 1).
    #expect(world.firstForestInCatchment(anchor: TileCoordinate(x: 3, y: 3), footprint: Footprint(width: 2, height: 2))
        == TileCoordinate(x: 1, y: 1))
}
