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
    // Before the first vehicle's age, so every haul walks one unit; the
    // handcart rules have their own tests.
    world.age = .antiquity
    for x in 0 ..< width {
        world.roadGraph.addRoad(at: TileCoordinate(x: x, y: 3))
    }
    return world
}

private let warehouseLimit = BuildingKind.warehouse.storagePerGood ?? 0

private func carriers(from producer: EntityID, in world: World) -> [Carrier.Mission] {
    world.carriers.values.sorted { $0.id.raw < $1.id.raw }.map(\.mission).filter { mission in
        if case .retrieve = mission { false } else { mission.source == producer }
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

/// Units of `goods` in every stockpile and every carrier.
private func total(of goods: [Good], in world: World) -> Int {
    let stored = world.stockpiles.values.reduce(0) { sum, pile in sum + goods.reduce(0) { $0 + pile.quantity(of: $1) } }
    let carried = world.carriers.values.reduce(0) { sum, carrier in
        goods.contains(carrier.mission.good) ? sum + carrier.mission.amount : sum
    }
    return stored + carried
}

@Test("scenario: a stuck producer gets no more inputs and nothing is lost")
func scenarioAStuckProducerGetsNoMoreInputsAndNothingIsLost() {
    var world = roadStrip()
    let sawmill = inject(.sawmill, in: &world, at: TileCoordinate(x: 1, y: 1), contents: [.planks: 15])
    let warehouse = inject(.warehouse, in: &world, at: TileCoordinate(x: 6, y: 0), contents: [.planks: warehouseLimit, .wood: 60])
    let before = total(of: [.wood, .planks], in: world)
    for _ in 0 ..< 2000 {
        world.tick()
    }
    #expect(total(of: [.wood, .planks], in: world) == before)
    #expect(world.stockpiles[warehouse]?.quantity(of: .wood) == 59)
    #expect(world.stockpiles[sawmill]?.quantity(of: .wood) == 1)
    #expect(world.buildingIssues()[sawmill] == .outputStuck(.planks))
}

@Test("scenario: a carrier whose store filled on the way goes on to one with room")
func scenarioACarrierWhoseStoreFilledOnTheWayGoesOnToOneWithRoom() {
    var world = roadStrip(width: 30)
    let bakery = inject(.bakery, in: &world, at: TileCoordinate(x: 1, y: 1), contents: [.bread: 10])
    let near = inject(.warehouse, in: &world, at: TileCoordinate(x: 6, y: 0))
    let far = inject(.warehouse, in: &world, at: TileCoordinate(x: 20, y: 0))
    world.tick()
    world.tick()
    #expect(world.carrierCountByProducer[bakery] == 2)
    world.stockpiles[near]?.deposit(.bread, amount: warehouseLimit)
    for _ in 0 ..< 3000 {
        world.tick()
    }
    #expect(world.stockpiles[far]?.quantity(of: .bread) == 10)
    #expect(world.stockpiles[bakery]?.quantity(of: .bread) == 0)
    #expect(total(of: [.bread], in: world) == warehouseLimit + 10)
}

@Test("scenario: a carrier with no store to go to takes its goods home")
func scenarioACarrierWithNoStoreToGoToTakesItsGoodsHome() {
    var world = roadStrip()
    let bakery = inject(.bakery, in: &world, at: TileCoordinate(x: 1, y: 1), contents: [.bread: 1])
    let warehouse = inject(.warehouse, in: &world, at: TileCoordinate(x: 14, y: 0))
    world.tick()
    world.stockpiles[warehouse]?.deposit(.bread, amount: warehouseLimit)
    for _ in 0 ..< 60 {
        world.tick()
    }
    #expect(world.carriers.isEmpty)
    #expect(world.stockpiles[bakery]?.quantity(of: .bread) == 1)
    #expect(world.carrierCountByProducer[bakery] == 0)
    world.stockpiles[warehouse]?.withdraw(.bread, amount: 1)
    for _ in 0 ..< 60 {
        world.tick()
    }
    #expect(world.stockpiles[warehouse]?.quantity(of: .bread) == warehouseLimit)
}

@Test("a carrier home with no room waits there until a store has room")
func aCarrierHomeWithNoRoomWaitsThereUntilAStoreHasRoom() {
    var world = roadStrip()
    let bakery = inject(.bakery, in: &world, at: TileCoordinate(x: 1, y: 1), contents: [.bread: 1])
    let warehouse = inject(.warehouse, in: &world, at: TileCoordinate(x: 14, y: 0))
    world.tick()
    world.stockpiles[warehouse]?.deposit(.bread, amount: warehouseLimit)
    world.stockpiles[bakery]?.deposit(.flour, amount: BuildingKind.bakery.storage ?? 0)
    for _ in 0 ..< 60 {
        world.tick()
    }
    #expect(world.carriers.count == 1)
    #expect(total(of: [.bread], in: world) == warehouseLimit + 1)
    world.stockpiles[warehouse]?.withdraw(.bread, amount: 1)
    for _ in 0 ..< 60 {
        world.tick()
    }
    #expect(world.stockpiles[warehouse]?.quantity(of: .bread) == warehouseLimit)
    #expect(world.carrierCountByProducer[bakery] == 0)
}

@Test("a supply carrier waits at a consumer that filled until it has room")
func aSupplyCarrierWaitsAtAConsumerThatFilledUntilItHasRoom() {
    var world = roadStrip()
    // Full of bread too, so the bakery's own bread has nowhere to go.
    let warehouse = inject(.warehouse, in: &world, at: TileCoordinate(x: 1, y: 0), contents: [.flour: 1, .bread: warehouseLimit])
    let bakery = inject(.bakery, in: &world, at: TileCoordinate(x: 14, y: 1))
    world.tick()
    #expect(world.stockpiles[warehouse]?.quantity(of: .flour) == 0)
    world.stockpiles[bakery]?.deposit(.bread, amount: BuildingKind.bakery.storage ?? 0)
    let retrievals = { (world: World) in
        world.carriers.values.count { if case .retrieve = $0.mission { true } else { false } }
    }
    for _ in 0 ..< 40 {
        world.tick()
    }
    #expect(retrievals(world) == 1)
    #expect(world.stockpiles[bakery]?.quantity(of: .flour) == 0)
    world.stockpiles[bakery]?.withdraw(.bread, amount: 1)
    world.tick()
    #expect(retrievals(world) == 0)
    #expect(world.stockpiles[bakery]?.quantity(of: .flour) == 1)
}
