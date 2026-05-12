import Foundation
import Testing
@testable import CityCore

// Tests for the per-island aggregate added by `add-island-hud-overlay`.
// Each `#### Scenario:` heading under `Requirement: Per-island stockpile
// aggregate in snapshot` and `Requirement: Tile-to-island lookup in
// snapshot` (in the warehouses-and-logistics + world-terrain spec files
// under openspec/changes/add-island-hud-overlay/specs/) maps to one
// `@Test("scenario: ...")` here.

// MARK: - Fixtures

/// Coastal world: left half grass, right half water, with enough room
/// to plant a couple of warehouses and one port straddling the shore.
private func shoreWorld(width: Int = 12, height: Int = 8) -> World {
    var world = World.fixtureWithTerrain(width: width, height: height, fill: .grass, seed: 7)
    for tileY in 0 ..< world.mapHeight {
        for tileX in 6 ..< world.mapWidth {
            world.terrainGrid[tileY * world.mapWidth + tileX] = .water
        }
    }
    // fixtureWithTerrain doesn't run the island detector; do it now so
    // the world has the metadata its snapshot needs.
    world.islands = IslandDetector.detectIslands(
        width: world.mapWidth,
        height: world.mapHeight,
        terrain: world.terrainGrid,
        mapHeightForClimate: world.mapHeight,
        seed: 7
    )
    world.economy.credit(100_000)
    return world
}

private func placeOperational(_ world: inout World, kind: BuildingKind, at anchor: TileCoordinate) -> EntityID {
    world.pendingCommands.append(.place(kind, at: anchor))
    _ = world.tick()
    let id = world.occupiedTiles[anchor]!
    let buildTicks = BuildingCatalog.spec(for: kind).buildDurationTicks
    for _ in 0 ..< buildTicks {
        _ = world.tick()
    }
    return id
}

// MARK: - Tile-to-island lookup

@Test("scenario: tile-to-island lookup resolves containing island")
func scenarioTileToIslandLookupResolvesContainingIsland() throws {
    let world = shoreWorld()
    let snapshot = world.snapshot()
    // (3, 3) is land.
    let id = snapshot.island(at: TileCoordinate(x: 3, y: 3))
    #expect(id != nil)
    // The world has exactly one connected land mass on the left half.
    let onlyIsland = try #require(world.islands.first?.id)
    #expect(id == onlyIsland)
}

@Test("scenario: water tile resolves to nil")
func scenarioWaterTileResolvesToNil() {
    let world = shoreWorld()
    let snapshot = world.snapshot()
    // (10, 4) is water.
    #expect(snapshot.island(at: TileCoordinate(x: 10, y: 4)) == nil)
}

@Test("scenario: archipelago tiles resolve to distinct islands")
func scenarioArchipelagoTilesResolveToDistinctIslands() {
    let world = World.newGame(layout: .archipelago, seed: 5)
    let snapshot = world.snapshot()
    let islands = world.islands
    #expect(islands.count >= 2)
    // For each island, sample a tile at its bounding-box center and
    // assert the lookup returns its ID.
    for island in islands {
        let centerX = (island.bounds.minX + island.bounds.maxX) / 2
        let centerY = (island.bounds.minY + island.bounds.maxY) / 2
        let resolved = snapshot.island(at: TileCoordinate(x: centerX, y: centerY))
        #expect(resolved == island.id, "expected island center to resolve to its own ID")
    }
}

// MARK: - IslandSummary aggregation

@Test("scenario: islandsummary aggregates warehouse and port stockpiles")
func scenarioIslandSummaryAggregatesWarehouseAndPortStockpiles() throws {
    var world = shoreWorld()
    let warehouseA = placeOperational(&world, kind: .warehouse, at: TileCoordinate(x: 0, y: 0))
    let warehouseB = placeOperational(&world, kind: .warehouse, at: TileCoordinate(x: 0, y: 3))
    let port = placeOperational(&world, kind: .port, at: TileCoordinate(x: 5, y: 0))
    if var stockpile = world.stockpiles[warehouseA] {
        _ = stockpile.deposit(.wood, amount: 6)
        world.stockpiles[warehouseA] = stockpile
    }
    if var stockpile = world.stockpiles[warehouseB] {
        _ = stockpile.deposit(.wood, amount: 6)
        world.stockpiles[warehouseB] = stockpile
    }
    if var stockpile = world.stockpiles[port] {
        _ = stockpile.deposit(.wood, amount: 3)
        world.stockpiles[port] = stockpile
    }
    let snapshot = world.snapshot()
    let onlyIsland = try #require(world.islands.first?.id)
    let summary = snapshot.islandSummaries[onlyIsland]
    #expect(summary != nil)
    #expect(summary?.stockpile[.wood] == 15)
}

@Test("scenario: producer internal stockpiles are excluded from the aggregate")
func scenarioProducerInternalStockpilesAreExcludedFromTheAggregate() throws {
    var world = shoreWorld()
    let sawmill = placeOperational(&world, kind: .sawmill, at: TileCoordinate(x: 1, y: 1))
    if var stockpile = world.stockpiles[sawmill] {
        _ = stockpile.deposit(.planks, amount: 5)
        world.stockpiles[sawmill] = stockpile
    }
    let snapshot = world.snapshot()
    let onlyIsland = try #require(world.islands.first?.id)
    let summary = snapshot.islandSummaries[onlyIsland]
    // Sawmill is a producer — its internal output stockpile MUST NOT
    // contribute to the aggregate. No warehouse / port / shipyard on
    // the island means planks stay invisible in the summary.
    #expect((summary?.stockpile[.planks] ?? 0) == 0)
}

@Test("scenario: empty island has zero stocks and zero capacity")
func scenarioEmptyIslandHasZeroStocksAndZeroCapacity() throws {
    let world = shoreWorld()
    let snapshot = world.snapshot()
    let onlyIsland = try #require(world.islands.first?.id)
    let summary = snapshot.islandSummaries[onlyIsland]
    #expect(summary != nil)
    let stocks = summary?.stockpile.values.reduce(0, +) ?? 0
    let capacity = summary?.capacity.values.reduce(0, +) ?? 0
    #expect(stocks == 0)
    #expect(capacity == 0)
}

@Test("scenario: capacity sums across all goods-buffers")
func scenarioCapacitySumsAcrossAllGoodsBuffers() throws {
    var world = shoreWorld()
    _ = placeOperational(&world, kind: .warehouse, at: TileCoordinate(x: 0, y: 0))
    _ = placeOperational(&world, kind: .port, at: TileCoordinate(x: 5, y: 0))
    let snapshot = world.snapshot()
    let onlyIsland = try #require(world.islands.first?.id)
    let summary = snapshot.islandSummaries[onlyIsland]
    // Warehouse capacity 200 + port capacity 200 = 400 total for any
    // good. (Catalog values from `World.stockpileCapacity(for:)`.)
    #expect(summary?.capacity[.wood] == 400)
    #expect(summary?.capacity[.planks] == 400)
    #expect(summary?.capacity[.food] == 400)
}

@Test("scenario: islandsummary carries the island name")
func scenarioIslandSummaryCarriesTheIslandName() {
    let world = World.newGame(layout: .archipelago, seed: 99)
    let snapshot = world.snapshot()
    for island in world.islands {
        let summary = snapshot.islandSummaries[island.id]
        #expect(summary?.name == island.name)
        #expect(summary?.bounds == island.bounds)
    }
}
