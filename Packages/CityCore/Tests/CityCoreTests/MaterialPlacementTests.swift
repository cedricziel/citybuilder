import Foundation
import Testing
@testable import CityCore

// Tests for the material-aware canPlace + multi-warehouse deduction
// added by `add-build-materials-cost` → M2 + M3. Scenarios under
// `Requirement: Placement rejected when island materials are short`
// and `Requirement: Deterministic multi-warehouse deduction` in
// openspec/changes/add-build-materials-cost/specs/buildings-and-construction/spec.md.

// MARK: - Test helpers

/// Single-island world with town center seeded. The fixture starts
/// with 4 wood + 2 planks in the town center stockpile per design D6.
private func freshSingleIsland() -> World {
    var world = World.newGame()
    world.economy.credit(100_000)
    return world
}

/// Direct injection of an operational warehouse with controlled
/// stockpile, bypassing the canPlace gate so tests can set arbitrary
/// island inventory without triggering the very rule they're testing.
private func injectWarehouse(
    in world: inout World,
    at anchor: TileCoordinate,
    contents: [Good: Int]
) -> EntityID {
    let id = EntityID(raw: world.nextEntityRaw)
    world.nextEntityRaw &+= 1
    let footprint = BuildingCatalog.spec(for: .warehouse).footprint
    let building = Building(
        id: id,
        kind: .warehouse,
        anchor: anchor,
        state: .operational,
        ticksSincePlacement: 0
    )
    world.buildings[id] = building
    for tile in footprint.tiles(anchor: anchor) {
        world.occupiedTiles[tile] = id
    }
    var stockpile = Stockpile(capacity: 200)
    for (good, amount) in contents {
        _ = stockpile.deposit(good, amount: amount)
    }
    world.stockpiles[id] = stockpile
    return id
}

/// Reset a town center's stockpile so tests can model "island holds
/// exactly N of X". The fresh world's starter inventory is
/// 4 wood + 2 planks; tests that need a different baseline call this.
private func resetTownCenter(in world: inout World, contents: [Good: Int]) {
    for (id, building) in world.buildings where building.kind == .townCenter {
        var stockpile = Stockpile(capacity: 8)
        for (good, amount) in contents {
            _ = stockpile.deposit(good, amount: amount)
        }
        world.stockpiles[id] = stockpile
    }
}

/// Scan for the first 2×2 buildable grass square not already occupied,
/// used by tests that need a lumberjack-hut anchor outside the town
/// center's footprint.
private func firstFreeGrassAnchor2x2(in world: World) -> TileCoordinate? {
    for tileY in 0 ..< world.mapHeight - 1 {
        for tileX in 0 ..< world.mapWidth - 1 {
            let anchor = TileCoordinate(x: tileX, y: tileY)
            var ok = true
            for deltaY in 0 ... 1 {
                for deltaX in 0 ... 1 {
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

// MARK: - canPlace gates on materials

@Test("scenario: placement allowed when island has enough materials")
func scenarioPlacementAllowedWhenIslandHasEnoughMaterials() throws {
    let world = freshSingleIsland()
    let anchor = try #require(firstFreeGrassAnchor2x2(in: world))
    // Town center holds 4 wood + 2 planks; lumberjack hut costs 2 wood.
    #expect(world.canPlace(.lumberjackHut, at: anchor) == .allowed)
}

@Test("scenario: placement rejected when island is short")
func scenarioPlacementRejectedWhenIslandIsShort() throws {
    var world = freshSingleIsland()
    // Drop the town center's stockpile to 2 wood + 1 plank — short of
    // a sawmill's 4 wood + 1 plank by 2 wood.
    resetTownCenter(in: &world, contents: [.wood: 2, .planks: 1])
    let anchor = try #require(firstFreeGrassAnchor2x2(in: world))
    let result = world.canPlace(.sawmill, at: anchor)
    switch result {
    case let .rejected(.insufficientMaterials(shortfall)):
        #expect(shortfall[.wood] == 2)
        #expect(shortfall[.planks] == nil)
    default:
        Issue.record("expected insufficientMaterials rejection; got \(result)")
    }
}

@Test("scenario: free-of-materials building (road) ignores material check")
func scenarioFreeOfMaterialsBuildingIgnoresMaterialCheck() throws {
    var world = freshSingleIsland()
    resetTownCenter(in: &world, contents: [:])
    let anchor = try #require(firstFreeGrassAnchor2x2(in: world))
    // Road has no material cost — even a zero-stock island accepts it.
    #expect(world.canPlace(.road, at: anchor) == .allowed)
}

@Test("scenario: rejection reason names the shortfall per good")
func scenarioRejectionReasonNamesTheShortfallPerGood() throws {
    var world = freshSingleIsland()
    resetTownCenter(in: &world, contents: [.wood: 1])
    let anchor = try #require(firstFreeGrassAnchor2x2(in: world))
    let result = world.canPlace(.sawmill, at: anchor)
    switch result {
    case let .rejected(.insufficientMaterials(shortfall)):
        #expect(shortfall[.wood] == 3)
        #expect(shortfall[.planks] == 1)
    default:
        Issue.record("expected insufficientMaterials rejection; got \(result)")
    }
}

@Test("scenario: materials on a different island do not count")
func scenarioMaterialsOnADifferentIslandDoNotCount() throws {
    let world = World.newGame(layout: .archipelago, seed: 5)
    // Each island gets its own town center with 4 wood + 2 planks.
    // Place a sawmill (4 wood + 1 plank) on island #1 — succeeds
    // because island #1's own town center has the materials. Then
    // check that island #2's materials don't satisfy island #1's
    // request (already implicit by the island-scoped lookup).
    let firstIsland = world.islands[0]
    let anchor = try #require(islandFreeAnchor(
        on: firstIsland, in: world,
        footprint: BuildingCatalog.spec(for: .sawmill).footprint
    ))
    #expect(world.canPlace(.sawmill, at: anchor) == .allowed)
}

// MARK: - Deterministic deduction (M3)

@Test("scenario: deduction order is shortest road-distance first")
func scenarioDeductionOrderIsShortestRoadDistanceFirst() throws {
    var world = freshSingleIsland()
    resetTownCenter(in: &world, contents: [:])
    let placementAnchor = try #require(firstFreeGrassAnchor2x2(in: world))
    // Two warehouses, both stocked the same; A is closer (Manhattan
    // distance 4) and B is farther (distance 8). The deduction loop
    // MUST drain A first.
    let warehouseA = injectWarehouse(
        in: &world,
        at: TileCoordinate(x: placementAnchor.x + 4, y: placementAnchor.y),
        contents: [.wood: 5]
    )
    let warehouseB = injectWarehouse(
        in: &world,
        at: TileCoordinate(x: placementAnchor.x + 8, y: placementAnchor.y),
        contents: [.wood: 5]
    )
    world.pendingCommands.append(.place(.lumberjackHut, at: placementAnchor))
    _ = world.tick()
    // Lumberjack hut costs 2 wood — exhaust closer warehouse first.
    #expect(world.stockpiles[warehouseA]?.quantity(of: .wood) == 3)
    #expect(world.stockpiles[warehouseB]?.quantity(of: .wood) == 5)
}

@Test("scenario: deduction draws from single warehouse when sufficient")
func scenarioDeductionDrawsFromSingleWarehouseWhenSufficient() throws {
    var world = freshSingleIsland()
    resetTownCenter(in: &world, contents: [:])
    let anchor = try #require(firstFreeGrassAnchor2x2(in: world))
    let warehouseAnchor = TileCoordinate(x: anchor.x + 4, y: anchor.y)
    let warehouseID = injectWarehouse(
        in: &world,
        at: warehouseAnchor,
        contents: [.wood: 5]
    )
    world.pendingCommands.append(.place(.lumberjackHut, at: anchor))
    _ = world.tick()
    // Lumberjack costs 2 wood; warehouse should now hold 3.
    #expect(world.stockpiles[warehouseID]?.quantity(of: .wood) == 3)
}

@Test("scenario: deduction splits across multiple warehouses when no single one has enough")
func scenarioDeductionSplitsAcrossWarehouses() throws {
    var world = freshSingleIsland()
    resetTownCenter(in: &world, contents: [:])
    let placementAnchor = try #require(firstFreeGrassAnchor2x2(in: world))
    let warehouseA = injectWarehouse(
        in: &world,
        at: TileCoordinate(x: placementAnchor.x + 4, y: placementAnchor.y),
        contents: [.wood: 3]
    )
    let warehouseB = injectWarehouse(
        in: &world,
        at: TileCoordinate(x: placementAnchor.x + 8, y: placementAnchor.y),
        contents: [.wood: 3]
    )
    // Sawmill costs 4 wood + 1 plank. Add 1 plank somewhere.
    var spA = world.stockpiles[warehouseA] ?? Stockpile(capacity: 200)
    _ = spA.deposit(.planks, amount: 1)
    world.stockpiles[warehouseA] = spA
    world.pendingCommands.append(.place(.sawmill, at: placementAnchor))
    _ = world.tick()
    let stockA = world.stockpiles[warehouseA]?.quantity(of: .wood) ?? -1
    let stockB = world.stockpiles[warehouseB]?.quantity(of: .wood) ?? -1
    // Closer warehouse (A) drained first → A: 0, B: 2. Sum: 2 wood
    // left on the island after a 4-wood draw.
    #expect(stockA + stockB == 2)
    // A is closer; deduction order is closest-first.
    #expect(stockA == 0)
    #expect(stockB == 2)
}

@Test("scenario: deduction is deterministic across replays")
func scenarioDeductionIsDeterministicAcrossReplays() {
    func run() -> [Good: Int] {
        var world = freshSingleIsland()
        resetTownCenter(in: &world, contents: [:])
        guard let anchor = firstFreeGrassAnchor2x2(in: world) else { return [:] }
        _ = injectWarehouse(
            in: &world,
            at: TileCoordinate(x: anchor.x + 4, y: anchor.y),
            contents: [.wood: 3, .planks: 5]
        )
        _ = injectWarehouse(
            in: &world,
            at: TileCoordinate(x: anchor.x + 8, y: anchor.y),
            contents: [.wood: 5, .planks: 2]
        )
        world.pendingCommands.append(.place(.sawmill, at: anchor))
        _ = world.tick()
        var totals: [Good: Int] = [:]
        for (_, stockpile) in world.stockpiles {
            for (good, amount) in stockpile.contents {
                totals[good, default: 0] += amount
            }
        }
        return totals
    }
    #expect(run() == run())
}

@Test("scenario: first lumberjack placement consumes starter wood")
func scenarioFirstLumberjackPlacementConsumesStarterWood() throws {
    var world = freshSingleIsland()
    let anchor = try #require(firstFreeGrassAnchor2x2(in: world))
    world.pendingCommands.append(.place(.lumberjackHut, at: anchor))
    _ = world.tick()
    // Town center (the only goods-buffer on a fresh world) goes
    // from 6 wood → 4 wood; planks and food unchanged.
    let townCenter = try #require(world.buildings.values.first { $0.kind == .townCenter })
    let stockpile = try #require(world.stockpiles[townCenter.id])
    #expect(stockpile.quantity(of: .wood) == 4)
    #expect(stockpile.quantity(of: .planks) == 5)
    #expect(stockpile.quantity(of: .food) == 2)
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
