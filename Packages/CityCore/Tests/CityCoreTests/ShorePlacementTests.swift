import Foundation
import Testing
@testable import CityCore

// Tests for the M4 shore-placement rule + face designation
// (specs/buildings-and-construction/spec.md).

private func mixedWorld() -> World {
    var world = World.fixtureWithTerrain(width: 12, height: 6, fill: .grass, seed: 1)
    // Right half (x ≥ 6) is water.
    for tileY in 0 ..< world.mapHeight {
        for tileX in 6 ..< world.mapWidth {
            world.terrainGrid[tileY * world.mapWidth + tileX] = .water
        }
    }
    return world
}

// MARK: - Shore-placement rule

@Test("scenario: building without shore-placement rule rejects mixed footprint")
func scenarioBuildingWithoutShorePlacementRuleRejectsMixedFootprint() {
    let world = mixedWorld()
    // Warehouse footprint (3×3) at (5, 1) covers x∈[5,7], straddling
    // land (x=5) and water (x=6,7). Warehouse does NOT opt into
    // shore-placement → must reject with terrain_not_buildable.
    let result = world.canPlace(.warehouse, at: TileCoordinate(x: 5, y: 1))
    #expect(result == .rejected(.terrainNotBuildable))
}

@Test("scenario: shore building rejected when below land minimum")
func scenarioShoreBuildingRejectedWhenBelowLandMinimum() {
    let world = mixedWorld()
    // Port footprint (2×3) at (7, 1) covers x∈[7,8], y∈[1,3] — all water.
    let result = world.canPlace(.port, at: TileCoordinate(x: 7, y: 1))
    #expect(result == .rejected(.shoreRequiresLandTile))
}

@Test("scenario: shore building rejected when below water minimum")
func scenarioShoreBuildingRejectedWhenBelowWaterMinimum() {
    let world = mixedWorld()
    // Port at (1, 1) covers x∈[1,2], y∈[1,3] — all grass.
    let result = world.canPlace(.port, at: TileCoordinate(x: 1, y: 1))
    #expect(result == .rejected(.shoreRequiresWaterTile))
}

@Test("scenario: shore building accepted when minima satisfied")
func scenarioShoreBuildingAcceptedWhenMinimaSatisfied() {
    let world = mixedWorld()
    // Port at (5, 1) covers x∈[5,6] — x=5 grass, x=6 water.
    #expect(world.canPlace(.port, at: TileCoordinate(x: 5, y: 1)) == .allowed)
}

// MARK: - Per-tile face designation

@Test("scenario: land face used for road adjacency")
func scenarioLandFaceUsedForRoadAdjacency() throws {
    var world = mixedWorld()
    world.pendingCommands.append(.place(.port, at: TileCoordinate(x: 5, y: 1)))
    world.economy.credit(10000)
    _ = world.tick()
    let portID = try #require(world.occupiedTiles[TileCoordinate(x: 5, y: 1)])
    let port = try #require(world.buildings[portID])
    // Land face must be the x=5 column tiles. Sea face must be x=6.
    #expect(port.landFaceTiles.contains(TileCoordinate(x: 5, y: 1)))
    #expect(!port.landFaceTiles.contains(TileCoordinate(x: 6, y: 1)))
}

@Test("scenario: sea face used for ship anchor")
func scenarioSeaFaceUsedForShipAnchor() throws {
    var world = mixedWorld()
    world.pendingCommands.append(.place(.port, at: TileCoordinate(x: 5, y: 1)))
    world.economy.credit(10000)
    _ = world.tick()
    let portID = try #require(world.occupiedTiles[TileCoordinate(x: 5, y: 1)])
    let port = try #require(world.buildings[portID])
    // Anchor must be one of the sea-face tiles.
    let anchor = try #require(port.shipAnchor)
    #expect(port.seaFaceTiles.contains(anchor))
}

@Test("scenario: face designation persists across save/load")
func scenarioFaceDesignationPersistsAcrossSaveLoad() throws {
    var world = mixedWorld()
    world.pendingCommands.append(.place(.port, at: TileCoordinate(x: 5, y: 1)))
    world.economy.credit(10000)
    _ = world.tick()
    let portID = try #require(world.occupiedTiles[TileCoordinate(x: 5, y: 1)])
    let saved = try JSONEncoder().encode(world)
    let loaded = try JSONDecoder().decode(World.self, from: saved)
    let original = try #require(world.buildings[portID])
    let restored = try #require(loaded.buildings[portID])
    #expect(restored.landFaceTiles == original.landFaceTiles)
    #expect(restored.seaFaceTiles == original.seaFaceTiles)
    #expect(restored.shipAnchor == original.shipAnchor)
}
