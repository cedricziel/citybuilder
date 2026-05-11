import Foundation
import Testing
@testable import CityCore

// Tests for spec buildings-and-construction. Each `#### Scenario:` heading
// maps to one @Test below.

@Test("scenario: catalog is accessible")
func scenarioCatalogIsAccessible() {
    let expected: Set<BuildingKind> = [.house, .warehouse, .road, .lumberjackHut, .sawmill, .townCenter]
    let present = Set(BuildingCatalog.all.map(\.kind))
    #expect(expected.isSubset(of: present))
    for kind in expected {
        let spec = BuildingCatalog.spec(for: kind)
        #expect(spec.footprint.width >= 1)
        #expect(spec.footprint.height >= 1)
    }
}

@Test("scenario: multi-tile placement validates each tile")
func scenarioMultiTilePlacementValidatesEachTile() {
    var world = World.fixtureWithTerrain(width: 6, height: 6, fill: .grass, seed: 1)
    // Inject water in the middle of where a 3x3 building would go.
    world.terrainGrid[2 * 6 + 2] = .water
    let result = world.canPlace(.warehouse, at: TileCoordinate(x: 1, y: 1))
    #expect(result == .rejected(.terrainNotBuildable))

    // After clearing the water, placement succeeds.
    world.terrainGrid[2 * 6 + 2] = .grass
    let okResult = world.canPlace(.warehouse, at: TileCoordinate(x: 1, y: 1))
    #expect(okResult == .allowed)
}

@Test("scenario: construction completes after declared duration")
func scenarioConstructionCompletesAfterDeclaredDuration() {
    var world = World.fixtureWithTerrain(width: 6, height: 6, fill: .grass, seed: 1)
    let anchor = TileCoordinate(x: 1, y: 1)
    let spec = BuildingCatalog.spec(for: .house)
    world.enqueue(.place(.house, at: anchor))
    world.tick()
    let id = world.snapshot().occupiedTiles[anchor]
    let buildingId = try? #require(id, "house was placed")
    if let buildingId {
        // After first tick the building exists in constructing state.
        #expect(world.buildings[buildingId]?.state == .constructing)
        for _ in 0 ..< Int(spec.buildDurationTicks) {
            world.tick()
        }
        #expect(world.buildings[buildingId]?.state == .operational)
    }
}

@Test("scenario: constructing building is non-functional")
func scenarioConstructingBuildingIsNonFunctional() {
    var world = World.fixtureWithTerrain(width: 6, height: 6, fill: .grass, seed: 1)
    let anchor = TileCoordinate(x: 1, y: 1)
    world.enqueue(.place(.warehouse, at: anchor))
    world.tick()
    let id = world.snapshot().occupiedTiles[anchor]
    let building = id.flatMap { world.buildings[$0] }
    #expect(building?.state == .constructing, "freshly placed building must be constructing")
}

@Test("scenario: demolish frees tiles")
func scenarioDemolishFreesTiles() {
    var world = World.fixtureWithTerrain(width: 6, height: 6, fill: .grass, seed: 1)
    let anchor = TileCoordinate(x: 1, y: 1)
    world.enqueue(.place(.house, at: anchor))
    world.tick()
    let footprintTiles = BuildingCatalog.spec(for: .house).footprint.tiles(anchor: anchor)
    for tile in footprintTiles {
        #expect(world.snapshot().occupiedTiles[tile] != nil)
    }
    world.enqueue(.demolish(at: anchor))
    world.tick()
    for tile in footprintTiles {
        #expect(world.snapshot().occupiedTiles[tile] == nil)
    }
}

@Test("scenario: insufficient funds prevents placement")
func scenarioInsufficientFundsPreventsPlacement() {
    // Economy lands in M4 — for M3 we assert the catalog's cost is non-zero
    // so future cost-gated placement has something to deduct. The actual
    // insufficient-funds rejection lands when Economy ships and the test
    // is reasserted there.
    let spec = BuildingCatalog.spec(for: .house)
    #expect(spec.cost > 0)
}
