import Testing
@testable import CityCore

// warehouses-and-logistics / Stores hold each good separately, and
// Producers ship only where there is room (openspec/changes/per-good-storage).

private func inject(
    _ kind: BuildingKind, in world: inout World, at anchor: TileCoordinate, contents: [Good: Int] = [:]
) -> EntityID {
    let id = EntityID(raw: world.nextEntityRaw)
    world.nextEntityRaw &+= 1
    world.buildings[id] = Building(id: id, kind: kind, anchor: anchor, state: .operational, owner: .player)
    for tile in BuildingCatalog.spec(for: kind).footprint.tiles(anchor: anchor) {
        world.occupiedTiles[tile] = id
    }
    var stockpile = World.newStockpile(for: kind)
    for (good, amount) in contents.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
        stockpile?.deposit(good, amount: amount)
    }
    world.stockpiles[id] = stockpile
    return id
}

/// A grass strip with a road along y = 3: 2×2 producers at y = 1 and
/// 3×3 stores at y = 0 touch it.
private func roadStrip(width: Int = 24) -> World {
    var world = World.fixtureWithTerrain(width: width, height: 6, fill: .grass, seed: 1)
    world.testMaterialCredits = [:]
    for x in 0 ..< width {
        world.roadGraph.addRoad(at: TileCoordinate(x: x, y: 3))
    }
    return world
}

private let warehouseLimit = BuildingKind.warehouse.storagePerGood ?? 0

private func carriers(from producer: EntityID, in world: World) -> [Carrier.Mission] {
    world.carriers.values.sorted { $0.id.raw < $1.id.raw }.map(\.mission).filter { mission in
        switch mission {
        case let .deliver(_, _, from, _), let .deliverToConstructionSite(_, _, from, _): from == producer
        case .retrieve: false
        }
    }
}

@Test("stores hold each good up to their per-good limit")
func storesHoldEachGoodUpToTheirPerGoodLimit() {
    #expect(BuildingKind.townCenter.storagePerGood == 40)
    #expect(BuildingKind.warehouse.storagePerGood == 80)
    #expect(BuildingKind.port.storagePerGood == 80)
    #expect(BuildingKind.townCenter.storage == nil)
    var pile = Stockpile(perGood: 80)
    #expect(pile.deposit(.bread, amount: 100) == 80)
    #expect(pile.room(for: .bread) == 0)
    #expect(pile.room(for: .iron) == 80)
    #expect(pile.deposit(.iron, amount: 5) == 5)
    #expect(pile.freeSpace == 80 * Good.allCases.count - 85)
}

@Test("a shared stockpile still pools its capacity")
func aSharedStockpileStillPoolsItsCapacity() {
    var pile = Stockpile(capacity: 16)
    #expect(pile.deposit(.bread, amount: 10) == 10)
    #expect(pile.room(for: .iron) == 6)
    #expect(!pile.limitsEachGood)
}

@Test("scenario: bread never crowds out iron")
func scenarioBreadNeverCrowdsOutIron() {
    var world = roadStrip()
    let smelter = inject(.smelter, in: &world, at: TileCoordinate(x: 1, y: 1), contents: [.iron: 1])
    let warehouse = inject(.warehouse, in: &world, at: TileCoordinate(x: 6, y: 0), contents: [.bread: warehouseLimit])
    world.tick()
    #expect(carriers(from: smelter, in: world) == [
        .deliver(good: .iron, amount: 1, fromProducer: smelter, toWarehouse: warehouse)
    ])
}

@Test("scenario: output with nowhere to go stays with its producer")
func scenarioOutputWithNowhereToGoStaysWithItsProducer() {
    var world = roadStrip()
    let bakery = inject(.bakery, in: &world, at: TileCoordinate(x: 1, y: 1), contents: [.bread: 1])
    _ = inject(.warehouse, in: &world, at: TileCoordinate(x: 6, y: 0), contents: [.bread: warehouseLimit])
    world.tick()
    #expect(carriers(from: bakery, in: world).isEmpty)
    #expect(world.stockpiles[bakery]?.quantity(of: .bread) == 1)
}

@Test("scenario: a producer whose output is stuck reports it")
func scenarioAProducerWhoseOutputIsStuckReportsIt() {
    var world = roadStrip()
    let capacity = BuildingKind.farm.storage ?? 0
    let farm = inject(.farm, in: &world, at: TileCoordinate(x: 1, y: 1), contents: [.food: capacity])
    _ = inject(.warehouse, in: &world, at: TileCoordinate(x: 6, y: 0), contents: [.food: warehouseLimit])
    world.tick()
    #expect(world.buildingIssues()[farm] == .outputStuck(.food))
    #expect(world.stockpiles[farm]?.quantity(of: .food) == capacity)
}

@Test("scenario: output leaves once the store has room again")
func scenarioOutputLeavesOnceTheStoreHasRoomAgain() {
    var world = roadStrip()
    let bakery = inject(.bakery, in: &world, at: TileCoordinate(x: 1, y: 1), contents: [.bread: 1])
    let warehouse = inject(.warehouse, in: &world, at: TileCoordinate(x: 6, y: 0), contents: [.bread: warehouseLimit])
    world.tick()
    world.stockpiles[warehouse]?.withdraw(.bread, amount: 1)
    world.tick()
    #expect(carriers(from: bakery, in: world) == [
        .deliver(good: .bread, amount: 1, fromProducer: bakery, toWarehouse: warehouse)
    ])
}

@Test("scenario: a store's room for a good is not promised twice")
func aStoresRoomForAGoodIsNotPromisedTwice() {
    var world = roadStrip()
    let first = inject(.bakery, in: &world, at: TileCoordinate(x: 1, y: 1), contents: [.bread: 1])
    let second = inject(.bakery, in: &world, at: TileCoordinate(x: 3, y: 1), contents: [.bread: 1])
    _ = inject(.warehouse, in: &world, at: TileCoordinate(x: 6, y: 0), contents: [.bread: warehouseLimit - 1])
    world.tick()
    #expect(carriers(from: first, in: world).count == 1)
    #expect(carriers(from: second, in: world).isEmpty)
}

@Test("scenario: bountiful harvest fills only the room for food")
func scenarioABountifulHarvestFillsOnlyTheRoomForFood() {
    var world = roadStrip()
    let center = inject(.townCenter, in: &world, at: TileCoordinate(x: 6, y: 0), contents: [.food: 35, .planks: 40])
    world.applyHistoryEvent(.bountifulHarvest)
    #expect(world.stockpiles[center]?.quantity(of: .food) == 40)
    #expect(world.stockpiles[center]?.quantity(of: .planks) == 40)
}

// port-and-shipyard / Port acts as a goods buffer.

@Test("scenario: carrier deposits into port from land")
func scenarioCarrierDepositsIntoPortFromLand() {
    var world = roadStrip()
    _ = inject(.lumberjackHut, in: &world, at: TileCoordinate(x: 1, y: 1), contents: [.wood: 1])
    let port = inject(.port, in: &world, at: TileCoordinate(x: 6, y: 0))
    for _ in 0 ..< 40 {
        world.tick()
    }
    #expect(world.carriers.isEmpty)
    #expect(world.stockpiles[port]?.quantity(of: .wood) == 1)
}

@Test("scenario: port respects buffer capacity on land-side deposit")
func scenarioPortRespectsBufferCapacityOnLandSideDeposit() {
    var world = roadStrip()
    let hut = inject(.lumberjackHut, in: &world, at: TileCoordinate(x: 1, y: 1), contents: [.wood: 1])
    _ = inject(.port, in: &world, at: TileCoordinate(x: 6, y: 0), contents: [.wood: BuildingKind.port.storagePerGood ?? 0])
    let warehouse = inject(.warehouse, in: &world, at: TileCoordinate(x: 14, y: 0))
    world.tick()
    #expect(carriers(from: hut, in: world) == [
        .deliver(good: .wood, amount: 1, fromProducer: hut, toWarehouse: warehouse)
    ])
}
