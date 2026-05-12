import Foundation
import Testing
@testable import CityCore

// Tests for the canPlace "allow-when-producer-supplies" rule added by
// `add-construction-stalls` → M2. Scenarios from
// openspec/changes/add-construction-stalls/specs/buildings-and-construction/spec.md
// under `Requirement: canPlace allowed when production exists`.

private func emptyTownCenter(in world: inout World) {
    for (id, building) in world.buildings where building.kind == .townCenter {
        world.stockpiles[id] = Stockpile(capacity: 8)
    }
}

private func injectOperational(
    in world: inout World,
    kind: BuildingKind,
    at anchor: TileCoordinate
) -> EntityID {
    let id = EntityID(raw: world.nextEntityRaw)
    world.nextEntityRaw &+= 1
    let footprint = BuildingCatalog.spec(for: kind).footprint
    world.buildings[id] = Building(
        id: id,
        kind: kind,
        anchor: anchor,
        state: .operational,
        ticksSincePlacement: 0
    )
    for tile in footprint.tiles(anchor: anchor) {
        world.occupiedTiles[tile] = id
    }
    return id
}

private func firstFreeGrassAnchor2x2(in world: World) -> TileCoordinate? {
    for tileY in 0 ..< world.mapHeight - 1 {
        for tileX in 0 ..< world.mapWidth - 1 {
            let anchor = TileCoordinate(x: tileX, y: tileY)
            var ok = true
            for deltaY in 0 ... 1 where ok {
                for deltaX in 0 ... 1 where ok {
                    let tile = TileCoordinate(x: tileX + deltaX, y: tileY + deltaY)
                    let terrainHere = world.terrain(at: tile) ?? .water
                    if terrainHere != .grass, terrainHere != .forest { ok = false }
                    if world.occupiedTiles[tile] != nil { ok = false }
                }
            }
            if ok { return anchor }
        }
    }
    return nil
}

@Test("scenario: placement allowed when warehouses are short but producers can supply")
func scenarioPlacementAllowedWhenWarehousesAreShortButProducersCanSupply() throws {
    var world = World.newGame()
    world.economy.credit(100_000)
    emptyTownCenter(in: &world)
    // No materials in any goods buffer; place a lumberjack hut as an
    // operational wood producer, then a sawmill as an operational
    // planks producer. A new sawmill placement (cost: 4 wood + 1 plank)
    // is queueable: producers cover both goods.
    let anchorA = try #require(firstFreeGrassAnchor2x2(in: world))
    _ = injectOperational(in: &world, kind: .lumberjackHut, at: anchorA)
    let anchorB = TileCoordinate(x: anchorA.x + 4, y: anchorA.y)
    _ = injectOperational(in: &world, kind: .sawmill, at: anchorB)
    let placementAnchor = TileCoordinate(x: anchorA.x, y: anchorA.y + 4)
    #expect(world.canPlace(.sawmill, at: placementAnchor) == .allowed)
}

@Test("scenario: placement rejected when neither warehouses nor producers can supply")
func scenarioPlacementRejectedWhenNeitherWarehousesNorProducersCanSupply() throws {
    var world = World.newGame()
    world.economy.credit(100_000)
    emptyTownCenter(in: &world)
    let anchor = try #require(firstFreeGrassAnchor2x2(in: world))
    let result = world.canPlace(.sawmill, at: anchor)
    switch result {
    case let .rejected(.insufficientMaterials(shortfall)):
        // No producers exist for wood OR planks on this island.
        #expect(shortfall[.wood] == 4)
        #expect(shortfall[.planks] == 1)
    default:
        Issue.record("expected insufficientMaterials; got \(result)")
    }
}

@Test("scenario: production check considers only operational producers on the placement island")
func scenarioProductionCheckConsidersOnlyOperationalProducersOnThePlacementIsland() throws {
    var world = World.newGame(layout: .archipelago, seed: 5)
    world.economy.credit(100_000)
    // Drain town centers so the rule has to depend on producers alone.
    for (id, building) in world.buildings where building.kind == .townCenter {
        world.stockpiles[id] = Stockpile(capacity: 8)
    }
    // Plant a lumberjack on Island #2; ask to place a sawmill on
    // Island #1. The producer on #2 must not count for #1.
    let secondIsland = world.islands[1]
    let secondAnchor = try #require(islandFreeAnchor(
        on: secondIsland, in: world,
        footprint: BuildingCatalog.spec(for: .lumberjackHut).footprint
    ))
    _ = injectOperational(in: &world, kind: .lumberjackHut, at: secondAnchor)
    let firstIsland = world.islands[0]
    let placementAnchor = try #require(islandFreeAnchor(
        on: firstIsland, in: world,
        footprint: BuildingCatalog.spec(for: .sawmill).footprint
    ))
    let result = world.canPlace(.sawmill, at: placementAnchor)
    guard case .rejected(.insufficientMaterials) = result else {
        Issue.record("expected rejection; got \(result)"); return
    }
}

// MARK: - Test helpers

private func islandFreeAnchor(
    on island: Island,
    in world: World,
    footprint: Footprint
) -> TileCoordinate? {
    for tileY in island.bounds.minY ... island.bounds.maxY {
        for tileX in island.bounds.minX ... island.bounds.maxX {
            let anchor = TileCoordinate(x: tileX, y: tileY)
            var ok = true
            for tile in footprint.tiles(anchor: anchor) {
                guard world.contains(tile) else { ok = false; break }
                let terrainHere = world.terrain(at: tile) ?? .water
                if terrainHere == .water { ok = false; break }
                if world.occupiedTiles[tile] != nil { ok = false; break }
            }
            if ok { return anchor }
        }
    }
    return nil
}
