import Foundation
import Testing
@testable import CityCore

// Tests for the deliverToConstructionSite carrier mission added by
// `add-construction-stalls` → M4 + M5.

/// Compact fixture: 16×6 grass world with a horizontal road that
/// connects a lumberjack hut (producer) and a sawmill construction
/// site (waiting consumer). Town center is gone (no starter inventory
/// — the test seeds materials by hand).
private func makeProducerSiteWorld() -> World {
    var world = World.fixtureWithTerrain(width: 16, height: 6, fill: .grass, seed: 99)
    world.economy.credit(100_000)
    world.testMaterialCredits = [:]
    world.islands = IslandDetector.detectIslands(
        width: world.mapWidth,
        height: world.mapHeight,
        terrain: world.terrainGrid,
        mapHeightForClimate: world.mapHeight,
        seed: 99
    )
    return world
}

/// Inject an operational lumberjack with a forest tile adjacent so it
/// produces wood. Returns its EntityID.
private func injectLumberjack(in world: inout World, at anchor: TileCoordinate) -> EntityID {
    let id = EntityID(raw: world.nextEntityRaw)
    world.nextEntityRaw &+= 1
    let footprint = BuildingCatalog.spec(for: .lumberjackHut).footprint
    world.buildings[id] = Building(
        id: id, kind: .lumberjackHut, anchor: anchor,
        state: .operational, ticksSincePlacement: 0
    )
    for tile in footprint.tiles(anchor: anchor) {
        world.occupiedTiles[tile] = id
    }
    world.stockpiles[id] = Stockpile(capacity: 16)
    return id
}

/// Inject a waiting sawmill construction site that needs `wood: 4,
/// planks: 1` to start. Returns its EntityID.
private func injectWaitingSawmill(in world: inout World, at anchor: TileCoordinate) -> EntityID {
    let id = EntityID(raw: world.nextEntityRaw)
    world.nextEntityRaw &+= 1
    let footprint = BuildingCatalog.spec(for: .sawmill).footprint
    world.buildings[id] = Building(
        id: id, kind: .sawmill, anchor: anchor,
        state: .constructing, ticksSincePlacement: 0,
        constructionState: .waitingForMaterials,
        materialsDelivered: [:]
    )
    for tile in footprint.tiles(anchor: anchor) {
        world.occupiedTiles[tile] = id
    }
    world.stockpiles[id] = Stockpile(capacity: 16)
    return id
}

/// Inject an operational warehouse and return its EntityID.
private func injectWarehouse(in world: inout World, at anchor: TileCoordinate) -> EntityID {
    let id = EntityID(raw: world.nextEntityRaw)
    world.nextEntityRaw &+= 1
    let footprint = BuildingCatalog.spec(for: .warehouse).footprint
    world.buildings[id] = Building(
        id: id, kind: .warehouse, anchor: anchor,
        state: .operational, ticksSincePlacement: 0
    )
    for tile in footprint.tiles(anchor: anchor) {
        world.occupiedTiles[tile] = id
    }
    world.stockpiles[id] = Stockpile(capacity: 200)
    return id
}

private func placeRoad(_ world: inout World, _ tiles: [TileCoordinate]) {
    for tile in tiles {
        let id = EntityID(raw: world.nextEntityRaw)
        world.nextEntityRaw &+= 1
        world.buildings[id] = Building(
            id: id, kind: .road, anchor: tile,
            state: .operational, ticksSincePlacement: 0
        )
        world.occupiedTiles[tile] = id
        world.roadGraph.addRoad(at: tile)
    }
}

@Test("scenario: carrier mission supports delivertoconstructionsite")
func scenarioCarrierMissionSupportsDeliverToConstructionSite() {
    // The mission's existence is the assertion. Constructing the
    // case must compile; pattern-matching it must work.
    let mission = Carrier.Mission.deliverToConstructionSite(
        good: .wood,
        amount: 1,
        fromProducer: EntityID(raw: 1),
        toBuilding: EntityID(raw: 2)
    )
    switch mission {
    case let .deliverToConstructionSite(good, amount, _, toBuilding):
        #expect(good == .wood)
        #expect(amount == 1)
        #expect(toBuilding.raw == 2)
    default:
        Issue.record("expected deliverToConstructionSite case")
    }
}

@Test("scenario: producer prioritizes waiting construction site over warehouse")
func scenarioProducerPrioritizesWaitingConstructionSiteOverWarehouse() {
    var world = makeProducerSiteWorld()
    // Lumberjack at (0,0)..(1,1), road along y=2, sawmill site at (4,3)..(5,4),
    // warehouse at (10,2)..(12,4). Forest at (0,3).
    world.terrainGrid[3 * world.mapWidth + 0] = .forest
    let lumberjack = injectLumberjack(in: &world, at: TileCoordinate(x: 0, y: 0))
    let road = (0 ..< 16).map { TileCoordinate(x: $0, y: 2) }
    placeRoad(&world, road)
    let site = injectWaitingSawmill(in: &world, at: TileCoordinate(x: 4, y: 3))
    _ = injectWarehouse(in: &world, at: TileCoordinate(x: 10, y: 3))
    // Hand-deposit wood into the lumberjack's output buffer so the
    // spawn loop has a payload to ship without waiting for cycles.
    if var stockpile = world.stockpiles[lumberjack] {
        _ = stockpile.deposit(.wood, amount: 1)
        world.stockpiles[lumberjack] = stockpile
    }
    _ = world.tick() // spawns a carrier
    let siteTargets = world.carriers.values.filter { carrier in
        if case let .deliverToConstructionSite(_, _, _, toBuilding) = carrier.mission {
            return toBuilding == site
        }
        return false
    }
    #expect(siteTargets.count == 1, "producer must prefer the waiting site over the warehouse")
}

@Test("scenario: construction-site delivery increments materialsdelivered on arrival")
func scenarioConstructionSiteDeliveryIncrementsMaterialsDeliveredOnArrival() {
    var world = makeProducerSiteWorld()
    world.terrainGrid[3 * world.mapWidth + 0] = .forest
    let lumberjack = injectLumberjack(in: &world, at: TileCoordinate(x: 0, y: 0))
    let road = (0 ..< 16).map { TileCoordinate(x: $0, y: 2) }
    placeRoad(&world, road)
    let site = injectWaitingSawmill(in: &world, at: TileCoordinate(x: 4, y: 3))
    if var stockpile = world.stockpiles[lumberjack] {
        _ = stockpile.deposit(.wood, amount: 1)
        world.stockpiles[lumberjack] = stockpile
    }
    // Tick until the carrier arrives at the site. The lumberjack is
    // adjacent to the road at y=2; the site is at (4,3) adjacent to
    // (4,2). Path length ~5 tiles. Cap at 20 ticks.
    for _ in 0 ..< 20 {
        _ = world.tick()
        let delivered = world.buildings[site]?.materialsDelivered[.wood] ?? 0
        if delivered > 0 { break }
    }
    let delivered = world.buildings[site]?.materialsDelivered[.wood] ?? 0
    #expect(delivered == 1)
}

@Test("scenario: waiting building does not advance tickssinceplacement")
func scenarioWaitingBuildingDoesNotAdvanceTicksSincePlacement() {
    var world = makeProducerSiteWorld()
    let site = injectWaitingSawmill(in: &world, at: TileCoordinate(x: 4, y: 3))
    for _ in 0 ..< 5 {
        _ = world.tick()
    }
    #expect(world.buildings[site]?.ticksSincePlacement == 0)
}

@Test("scenario: constructionstarted emitted on the flip tick")
func scenarioConstructionStartedEmittedOnTheFlipTick() {
    // Mirror of "building flips to actively..." — the spec lists the
    // event-emission requirement under world-events and the materials
    // tracking under buildings-and-construction; both scenarios refer
    // to the same flip tick. Test the event side here.
    var world = makeProducerSiteWorld()
    let site = injectWaitingSawmill(in: &world, at: TileCoordinate(x: 4, y: 3))
    let road = (0 ..< 16).map { TileCoordinate(x: $0, y: 2) }
    placeRoad(&world, road)
    for _ in 0 ..< 4 {
        let carrierID = EntityID(raw: world.nextEntityRaw)
        world.nextEntityRaw &+= 1
        world.carriers[carrierID] = Carrier(
            id: carrierID,
            path: [TileCoordinate(x: 4, y: 2)],
            mission: .deliverToConstructionSite(
                good: .wood, amount: 1,
                fromProducer: EntityID(raw: 1), toBuilding: site
            )
        )
        _ = world.tick()
    }
    let carrierID = EntityID(raw: world.nextEntityRaw)
    world.nextEntityRaw &+= 1
    world.carriers[carrierID] = Carrier(
        id: carrierID,
        path: [TileCoordinate(x: 4, y: 2)],
        mission: .deliverToConstructionSite(
            good: .planks, amount: 1,
            fromProducer: EntityID(raw: 1), toBuilding: site
        )
    )
    let result = world.tick()
    let started = result.events.filter { event in
        if case .constructionStarted = event { return true }
        return false
    }
    #expect(started.count == 1)
}

@Test("scenario: constructionstarted event fires on the flip tick")
func scenarioConstructionStartedEventFiresOnTheFlipTick() throws {
    // warehouses-and-logistics restates the same flip-tick assertion
    // from the carrier perspective. Reuse the same fixture and just
    // re-emit so scenario coverage is honest.
    try scenarioConstructionStartedEmittedOnTheFlipTick()
}

@Test("scenario: producer falls back to warehouse when no waiting site needs the good")
func scenarioProducerFallsBackToWarehouseWhenNoWaitingSiteNeedsTheGood() {
    var world = makeProducerSiteWorld()
    world.terrainGrid[3 * world.mapWidth + 0] = .forest
    let lumberjack = injectLumberjack(in: &world, at: TileCoordinate(x: 0, y: 0))
    let road = (0 ..< 16).map { TileCoordinate(x: $0, y: 2) }
    placeRoad(&world, road)
    let warehouse = injectWarehouse(in: &world, at: TileCoordinate(x: 10, y: 3))
    // NO waiting site — the producer must route to the warehouse.
    if var stockpile = world.stockpiles[lumberjack] {
        _ = stockpile.deposit(.wood, amount: 1)
        world.stockpiles[lumberjack] = stockpile
    }
    _ = world.tick()
    let warehouseTargets = world.carriers.values.filter { carrier in
        if case let .deliver(_, _, _, toWarehouse) = carrier.mission {
            return toWarehouse == warehouse
        }
        return false
    }
    #expect(warehouseTargets.count == 1)
}

@Test("scenario: building flips to actively when materialsdelivered satisfies materialcost")
func scenarioBuildingFlipsToActivelyWhenMaterialsDeliveredSatisfiesMaterialCost() {
    var world = makeProducerSiteWorld()
    let site = injectWaitingSawmill(in: &world, at: TileCoordinate(x: 4, y: 3))
    // Hand-set delivered to satisfy the recipe via the carrier-arrival
    // path. Easiest way is to feed the building directly with a
    // synthetic carrier delivery: create a deliver carrier already at
    // its destination so the next tick triggers applyCarrierArrival.
    let road = (0 ..< 16).map { TileCoordinate(x: $0, y: 2) }
    placeRoad(&world, road)
    // Deliver the 4 wood through synthetic carrier hops.
    for _ in 0 ..< 4 {
        let carrierID = EntityID(raw: world.nextEntityRaw)
        world.nextEntityRaw &+= 1
        world.carriers[carrierID] = Carrier(
            id: carrierID,
            path: [TileCoordinate(x: 4, y: 2)],
            mission: .deliverToConstructionSite(
                good: .wood, amount: 1,
                fromProducer: EntityID(raw: 1), toBuilding: site
            )
        )
        _ = world.tick()
    }
    // Deliver the 1 plank.
    let carrierID = EntityID(raw: world.nextEntityRaw)
    world.nextEntityRaw &+= 1
    world.carriers[carrierID] = Carrier(
        id: carrierID,
        path: [TileCoordinate(x: 4, y: 2)],
        mission: .deliverToConstructionSite(
            good: .planks, amount: 1,
            fromProducer: EntityID(raw: 1), toBuilding: site
        )
    )
    let result = world.tick()
    #expect(world.buildings[site]?.constructionState == .actively)
    let hasStarted = result.events.contains { event in
        if case let .constructionStarted(building) = event { return building == site }
        return false
    }
    #expect(hasStarted)
}
