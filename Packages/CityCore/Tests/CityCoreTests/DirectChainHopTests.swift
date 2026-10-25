import Foundation
import Testing
@testable import CityCore

// warehouses-and-logistics / Producers deliver to short consumers
// (openspec/changes/visible-distribution, milestone 1).

private func inject(
    _ kind: BuildingKind,
    in world: inout World,
    at anchor: TileCoordinate,
    contents: [Good: Int] = [:],
    owner: Owner = .player
) -> EntityID {
    let id = EntityID(raw: world.nextEntityRaw)
    world.nextEntityRaw &+= 1
    world.buildings[id] = Building(
        id: id, kind: kind, anchor: anchor, state: .operational, ticksSincePlacement: 0, owner: owner
    )
    for tile in BuildingCatalog.spec(for: kind).footprint.tiles(anchor: anchor) {
        world.occupiedTiles[tile] = id
    }
    var stockpile = World.newStockpile(for: kind) ?? Stockpile(capacity: 200)
    for (good, amount) in contents {
        _ = stockpile.deposit(good, amount: amount)
    }
    world.stockpiles[id] = stockpile
    return id
}

/// A grass strip with a road along y = 3, so 2×2 workshops at y = 1 and
/// 3×3 buffers at y = 0 all touch it.
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

private func missions(from producer: EntityID, in world: World) -> [Carrier.Mission] {
    world.carriers.values.sorted { $0.id.raw < $1.id.raw }.map(\.mission).filter { mission in
        switch mission {
        case let .deliver(_, _, from, _), let .deliverToConsumer(_, _, from, _),
             let .deliverToConstructionSite(_, _, from, _):
            from == producer
        case .retrieve:
            false
        }
    }
}

private func retrievals(to consumer: EntityID, in world: World) -> Int {
    world.carriers.values.count { carrier in
        if case let .retrieve(_, _, _, to) = carrier.mission { return to == consumer }
        return false
    }
}

@Test("scenario: flour goes straight to a short bakery")
func scenarioFlourGoesStraightToAShortBakery() {
    var world = roadStrip()
    let windmill = inject(.windmill, in: &world, at: TileCoordinate(x: 1, y: 1), contents: [.flour: 1])
    _ = inject(.warehouse, in: &world, at: TileCoordinate(x: 6, y: 0))
    let bakery = inject(.bakery, in: &world, at: TileCoordinate(x: 14, y: 1))
    world.tick()
    #expect(missions(from: windmill, in: world) == [
        .deliverToConsumer(good: .flour, amount: 1, fromProducer: windmill, toConsumer: bakery)
    ])
}

@Test("scenario: output goes to storage when no consumer is short")
func scenarioOutputGoesToStorageWhenNoConsumerIsShort() {
    var world = roadStrip()
    let windmill = inject(.windmill, in: &world, at: TileCoordinate(x: 1, y: 1), contents: [.flour: 1])
    let warehouse = inject(.warehouse, in: &world, at: TileCoordinate(x: 6, y: 0))
    _ = inject(.bakery, in: &world, at: TileCoordinate(x: 14, y: 1), contents: [.flour: 2])
    world.tick()
    #expect(missions(from: windmill, in: world) == [
        .deliver(good: .flour, amount: 1, fromProducer: windmill, toWarehouse: warehouse)
    ])
}

@Test("scenario: a consumer fed directly gets no extra supply carrier")
func scenarioAConsumerFedDirectlyGetsNoExtraSupplyCarrier() {
    var world = roadStrip()
    _ = inject(.windmill, in: &world, at: TileCoordinate(x: 1, y: 1), contents: [.flour: 1])
    _ = inject(.warehouse, in: &world, at: TileCoordinate(x: 6, y: 0), contents: [.flour: 5])
    let bakery = inject(.bakery, in: &world, at: TileCoordinate(x: 14, y: 1), contents: [.flour: 1])
    world.tick()
    #expect(world.inboundUnits(to: bakery, good: .flour).ofGood == 1)
    #expect(retrievals(to: bakery, in: world) == 0)
}

@Test("scenario: ties go to the lower entity ID")
func scenarioTiesGoToTheLowerEntityID() {
    var world = roadStrip()
    // Both bakeries' roads lie 5 tiles from the windmill's road at x = 8.
    let left = inject(.bakery, in: &world, at: TileCoordinate(x: 3, y: 1))
    _ = inject(.bakery, in: &world, at: TileCoordinate(x: 13, y: 1))
    let windmill = inject(.windmill, in: &world, at: TileCoordinate(x: 8, y: 1), contents: [.flour: 1])
    world.tick()
    #expect(missions(from: windmill, in: world) == [
        .deliverToConsumer(good: .flour, amount: 1, fromProducer: windmill, toConsumer: left)
    ])
}

@Test("a consumer with no room left gets no delivery")
func aConsumerWithNoRoomLeftGetsNoDelivery() {
    var world = roadStrip()
    let windmill = inject(.windmill, in: &world, at: TileCoordinate(x: 1, y: 1), contents: [.flour: 1])
    let warehouse = inject(.warehouse, in: &world, at: TileCoordinate(x: 14, y: 0))
    let bakery = inject(.bakery, in: &world, at: TileCoordinate(x: 6, y: 1))
    world.stockpiles[bakery] = Stockpile(capacity: 4)
    _ = world.stockpiles[bakery]?.deposit(.bread, amount: 4)
    world.tick()
    #expect(missions(from: windmill, in: world) == [
        .deliver(good: .flour, amount: 1, fromProducer: windmill, toWarehouse: warehouse)
    ])
}

@Test("scenario: construction materials still go to storage")
func scenarioConstructionMaterialsStillGoToStorage() {
    var world = roadStrip()
    let hut = inject(.lumberjackHut, in: &world, at: TileCoordinate(x: 1, y: 1), contents: [.wood: 1])
    let warehouse = inject(.warehouse, in: &world, at: TileCoordinate(x: 14, y: 0))
    _ = inject(.sawmill, in: &world, at: TileCoordinate(x: 6, y: 1))
    world.tick()
    #expect(missions(from: hut, in: world) == [
        .deliver(good: .wood, amount: 1, fromProducer: hut, toWarehouse: warehouse)
    ])
}

@Test("scenario: goods houses need still go to storage")
func scenarioGoodsHousesNeedStillGoToStorage() {
    var world = roadStrip()
    let bakery = inject(.bakery, in: &world, at: TileCoordinate(x: 1, y: 1), contents: [.bread: 1])
    let warehouse = inject(.warehouse, in: &world, at: TileCoordinate(x: 14, y: 0))
    _ = inject(.monument, in: &world, at: TileCoordinate(x: 5, y: 0))
    world.tick()
    #expect(missions(from: bakery, in: world) == [
        .deliver(good: .bread, amount: 1, fromProducer: bakery, toWarehouse: warehouse)
    ])
}

@Test("a direct delivery stocks the consumer and frees the producer's carrier slot")
func aDirectDeliveryStocksTheConsumerAndFreesTheProducersCarrierSlot() {
    var world = roadStrip()
    let windmill = inject(.windmill, in: &world, at: TileCoordinate(x: 1, y: 1), contents: [.flour: 1])
    let bakery = inject(.bakery, in: &world, at: TileCoordinate(x: 6, y: 1))
    world.tick()
    #expect(world.carrierCountByProducer[windmill] == 1)
    for _ in 0 ..< 10 where !world.carriers.isEmpty {
        world.tick()
    }
    #expect(world.carriers.isEmpty)
    #expect(world.carrierCountByProducer[windmill] == 0)
    #expect(world.stockpiles[bakery]?.quantity(of: .flour) == 1)
}

@Test("a producer does not deliver to another owner's consumer")
func aProducerDoesNotDeliverToAnotherOwnersConsumer() {
    var world = roadStrip()
    let windmill = inject(.windmill, in: &world, at: TileCoordinate(x: 1, y: 1), contents: [.flour: 1])
    let warehouse = inject(.warehouse, in: &world, at: TileCoordinate(x: 14, y: 0))
    _ = inject(.bakery, in: &world, at: TileCoordinate(x: 6, y: 1), owner: .rival(1))
    world.tick()
    #expect(missions(from: windmill, in: world) == [
        .deliver(good: .flour, amount: 1, fromProducer: windmill, toWarehouse: warehouse)
    ])
}

@Test("a consumer off the producer's road network is not short for it")
func aConsumerOffTheProducersRoadNetworkIsNotShortForIt() {
    var world = roadStrip()
    let windmill = inject(.windmill, in: &world, at: TileCoordinate(x: 1, y: 1), contents: [.flour: 1])
    let warehouse = inject(.warehouse, in: &world, at: TileCoordinate(x: 5, y: 0))
    world.roadGraph.removeRoad(at: TileCoordinate(x: 10, y: 3))
    _ = inject(.bakery, in: &world, at: TileCoordinate(x: 14, y: 1))
    world.tick()
    #expect(missions(from: windmill, in: world) == [
        .deliver(good: .flour, amount: 1, fromProducer: windmill, toWarehouse: warehouse)
    ])
}

@Test("a direct delivery mission survives a save round trip")
func aDirectDeliveryMissionSurvivesASaveRoundTrip() throws {
    let mission = Carrier.Mission.deliverToConsumer(
        good: .flour, amount: 1, fromProducer: EntityID(raw: 3), toConsumer: EntityID(raw: 9)
    )
    let data = try JSONEncoder().encode(mission)
    #expect(try JSONDecoder().decode(Carrier.Mission.self, from: data) == mission)
}

private func flour(in world: World, _ ids: [EntityID]) -> Int {
    let stored = ids.reduce(0) { $0 + (world.stockpiles[$1]?.quantity(of: .flour) ?? 0) }
    let carried = world.carriers.values.reduce(0) { sum, carrier in
        carrier.mission.good == .flour ? sum + carrier.mission.amount : sum
    }
    return stored + carried
}

@Test("a second producer in the same tick sees the first one's delivery")
func aSecondProducerInTheSameTickSeesTheFirstOnesDelivery() {
    var world = roadStrip()
    let first = inject(.windmill, in: &world, at: TileCoordinate(x: 1, y: 1), contents: [.flour: 1])
    let second = inject(.windmill, in: &world, at: TileCoordinate(x: 4, y: 1), contents: [.flour: 1])
    let warehouse = inject(.warehouse, in: &world, at: TileCoordinate(x: 18, y: 0))
    // One unit brings the bakery to twice its recipe amount.
    let bakery = inject(.bakery, in: &world, at: TileCoordinate(x: 9, y: 1), contents: [.flour: 1])
    world.tick()
    #expect(missions(from: first, in: world) == [
        .deliverToConsumer(good: .flour, amount: 1, fromProducer: first, toConsumer: bakery)
    ])
    #expect(missions(from: second, in: world) == [
        .deliver(good: .flour, amount: 1, fromProducer: second, toWarehouse: warehouse)
    ])
}

@Test("scenario: goods for a consumer that filled up go to storage")
func scenarioGoodsForAConsumerThatFilledUpGoToStorage() {
    var world = roadStrip()
    let windmill = inject(.windmill, in: &world, at: TileCoordinate(x: 1, y: 1), contents: [.flour: 1])
    let bakery = inject(.bakery, in: &world, at: TileCoordinate(x: 6, y: 1))
    let warehouse = inject(.warehouse, in: &world, at: TileCoordinate(x: 14, y: 0))
    world.tick()
    world.stockpiles[bakery] = Stockpile(capacity: 0)
    for _ in 0 ..< 40 where !world.carriers.isEmpty {
        world.tick()
    }
    #expect(world.carriers.isEmpty)
    #expect(world.stockpiles[warehouse]?.quantity(of: .flour) == 1)
    #expect(world.carrierCountByProducer[windmill] == 0)
}

@Test("scenario: goods for a demolished consumer go to storage")
func scenarioGoodsForADemolishedConsumerGoToStorage() {
    var world = roadStrip()
    let windmill = inject(.windmill, in: &world, at: TileCoordinate(x: 1, y: 1), contents: [.flour: 1])
    let warehouse = inject(.warehouse, in: &world, at: TileCoordinate(x: 18, y: 0))
    let bakery = inject(.bakery, in: &world, at: TileCoordinate(x: 12, y: 1))
    world.tick()
    var events: [WorldEvent] = []
    world.applyDemolish(anchor: TileCoordinate(x: 12, y: 1), events: &events)
    #expect(world.buildings[bakery] == nil)
    for _ in 0 ..< 60 where !world.carriers.isEmpty {
        world.tick()
    }
    #expect(world.carriers.isEmpty)
    #expect(world.stockpiles[warehouse]?.quantity(of: .flour) == 1)
    #expect(flour(in: world, [windmill, warehouse]) == 1)
}

@Test("goods with no storage left go back to where they came from")
func goodsWithNoStorageLeftGoBackToWhereTheyCameFrom() {
    var world = roadStrip()
    let windmill = inject(.windmill, in: &world, at: TileCoordinate(x: 1, y: 1), contents: [.flour: 1])
    _ = inject(.bakery, in: &world, at: TileCoordinate(x: 12, y: 1))
    world.tick()
    var events: [WorldEvent] = []
    world.applyDemolish(anchor: TileCoordinate(x: 12, y: 1), events: &events)
    for _ in 0 ..< 60 where !world.carriers.isEmpty {
        world.tick()
    }
    #expect(world.carriers.isEmpty)
    #expect(world.stockpiles[windmill]?.quantity(of: .flour) == 1)
}

@Test("a delivery to a demolished warehouse goes to the next one")
func aDeliveryToADemolishedWarehouseGoesToTheNextOne() {
    var world = roadStrip(width: 30)
    _ = inject(.lumberjackHut, in: &world, at: TileCoordinate(x: 1, y: 1), contents: [.wood: 1])
    _ = inject(.warehouse, in: &world, at: TileCoordinate(x: 6, y: 0))
    let far = inject(.warehouse, in: &world, at: TileCoordinate(x: 20, y: 0))
    world.tick()
    var events: [WorldEvent] = []
    world.applyDemolish(anchor: TileCoordinate(x: 6, y: 0), events: &events)
    for _ in 0 ..< 60 where !world.carriers.isEmpty {
        world.tick()
    }
    #expect(world.stockpiles[far]?.quantity(of: .wood) == 1)
}

@Test("a retrieval for a demolished consumer goes back to storage")
func aRetrievalForADemolishedConsumerGoesBackToStorage() {
    var world = roadStrip()
    let warehouse = inject(.warehouse, in: &world, at: TileCoordinate(x: 1, y: 0), contents: [.flour: 1])
    _ = inject(.bakery, in: &world, at: TileCoordinate(x: 14, y: 1))
    world.tick()
    #expect(world.stockpiles[warehouse]?.quantity(of: .flour) == 0)
    var events: [WorldEvent] = []
    world.applyDemolish(anchor: TileCoordinate(x: 14, y: 1), events: &events)
    for _ in 0 ..< 60 where !world.carriers.isEmpty {
        world.tick()
    }
    #expect(world.carriers.isEmpty)
    #expect(world.stockpiles[warehouse]?.quantity(of: .flour) == 1)
}

@Test("goods for a full consumer with no room anywhere wait with their carrier")
func goodsForAFullConsumerWithNoRoomAnywhereWaitWithTheirCarrier() {
    var world = roadStrip()
    let windmill = inject(.windmill, in: &world, at: TileCoordinate(x: 1, y: 1), contents: [.flour: 1])
    let bakery = inject(.bakery, in: &world, at: TileCoordinate(x: 6, y: 1))
    world.tick()
    world.stockpiles[bakery] = Stockpile(capacity: 0)
    world.stockpiles[windmill] = Stockpile(capacity: 0)
    for _ in 0 ..< 40 {
        world.tick()
    }
    #expect(world.carriers.count == 1)
    #expect(flour(in: world, [windmill, bakery]) == 1)
}

@Test("goods for a demolished consumer with no room anywhere are dropped as before")
func goodsForADemolishedConsumerWithNoRoomAnywhereAreDroppedAsBefore() {
    var world = roadStrip()
    let windmill = inject(.windmill, in: &world, at: TileCoordinate(x: 1, y: 1), contents: [.flour: 1])
    _ = inject(.bakery, in: &world, at: TileCoordinate(x: 6, y: 1))
    world.tick()
    var events: [WorldEvent] = []
    world.applyDemolish(anchor: TileCoordinate(x: 6, y: 1), events: &events)
    world.stockpiles[windmill] = Stockpile(capacity: 0)
    for _ in 0 ..< 40 where !world.carriers.isEmpty {
        world.tick()
    }
    #expect(world.carriers.isEmpty)
    #expect(world.carrierCountByProducer[windmill] == 0)
}

@Test("the storage-goods rule follows the owner's culture")
func theStorageGoodsRuleFollowsTheOwnersCulture() {
    var world = roadStrip()
    world.testSeatRival()
    let rivalLuxury = world.culture(of: .rival(1)).luxury
    #expect(rivalLuxury != world.culture(of: .player).luxury)
    #expect(world.goesThroughStorage(rivalLuxury, for: .rival(1)))
    #expect(!world.goesThroughStorage(rivalLuxury, for: .player))
    #expect(world.goesThroughStorage(.wood, for: .rival(1)))
    #expect(!world.goesThroughStorage(.flour, for: .rival(1)))
}

@Test("a world with a direct delivery in flight survives a save round trip")
func aWorldWithADirectDeliveryInFlightSurvivesASaveRoundTrip() throws {
    var world = roadStrip()
    _ = inject(.windmill, in: &world, at: TileCoordinate(x: 1, y: 1), contents: [.flour: 1])
    _ = inject(.bakery, in: &world, at: TileCoordinate(x: 12, y: 1))
    world.tick()
    world.tick()
    #expect(world.carriers.values.contains { if case .deliverToConsumer = $0.mission { true } else { false } })
    let decoded = try JSONDecoder().decode(World.self, from: JSONEncoder().encode(world))
    #expect(decoded == world)
    var original = world, restored = decoded
    for _ in 0 ..< 20 {
        original.tick()
        restored.tick()
    }
    #expect(original == restored)
}

@Test("the determinism fixture's chain sends goods straight to consumers")
func theDeterminismFixturesChainSendsGoodsStraightToConsumers() {
    var world = World.chainFixture()
    var hopped: Set<Good> = []
    for _ in 0 ..< 600 {
        world.tick()
        for carrier in world.carriers.values {
            if case let .deliverToConsumer(good, _, _, _) = carrier.mission { hopped.insert(good) }
        }
    }
    #expect(hopped == [.grain, .flour])
}

@Test("every mission reports its trip and keeps its kind when it carries less")
func everyMissionReportsItsTripAndKeepsItsKindWhenItCarriesLess() {
    let from = EntityID(raw: 1), to = EntityID(raw: 2), elsewhere = EntityID(raw: 3)
    let missions: [Carrier.Mission] = [
        .deliver(good: .flour, amount: 3, fromProducer: from, toWarehouse: to),
        .retrieve(good: .flour, amount: 3, fromWarehouse: from, toConsumer: to),
        .deliverToConsumer(good: .flour, amount: 3, fromProducer: from, toConsumer: to),
        .deliverToConstructionSite(good: .flour, amount: 3, fromProducer: from, toBuilding: to)
    ]
    for mission in missions {
        #expect(mission.good == .flour && mission.amount == 3)
        #expect(mission.source == from && mission.destination == to)
        let fewer = mission.carrying(1)
        #expect(fewer.amount == 1 && fewer.destination == to && fewer.source == from)
        let onward = mission.redirected(to: elsewhere, amount: 1)
        #expect(onward.destination == elsewhere && onward.amount == 1)
    }
    #expect(missions[1].redirected(to: elsewhere, amount: 1)
        == .retrieve(good: .flour, amount: 1, fromWarehouse: from, toConsumer: elsewhere))
    #expect(missions[2].redirected(to: elsewhere, amount: 1)
        == .deliver(good: .flour, amount: 1, fromProducer: from, toWarehouse: elsewhere))
}

@Test("goods whose source and destination are both demolished still go to storage")
func goodsWhoseSourceAndDestinationAreBothDemolishedStillGoToStorage() {
    var world = roadStrip()
    _ = inject(.windmill, in: &world, at: TileCoordinate(x: 1, y: 1), contents: [.flour: 1])
    _ = inject(.bakery, in: &world, at: TileCoordinate(x: 6, y: 1))
    let warehouse = inject(.warehouse, in: &world, at: TileCoordinate(x: 14, y: 0))
    world.tick()
    var events: [WorldEvent] = []
    world.applyDemolish(anchor: TileCoordinate(x: 6, y: 1), events: &events)
    world.applyDemolish(anchor: TileCoordinate(x: 1, y: 1), events: &events)
    for _ in 0 ..< 60 where !world.carriers.isEmpty {
        world.tick()
    }
    #expect(world.carriers.isEmpty)
    #expect(world.stockpiles[warehouse]?.quantity(of: .flour) == 1)
}

@Test("a retrieval sent on to a store that fills goes on to the next one")
func aRetrievalSentOnToAStoreThatFillsGoesOnToTheNextOne() {
    var world = roadStrip(width: 30)
    let near = inject(.warehouse, in: &world, at: TileCoordinate(x: 1, y: 0), contents: [.flour: 1])
    _ = inject(.bakery, in: &world, at: TileCoordinate(x: 10, y: 1))
    let far = inject(.warehouse, in: &world, at: TileCoordinate(x: 22, y: 0))
    world.tick()
    var events: [WorldEvent] = []
    world.applyDemolish(anchor: TileCoordinate(x: 10, y: 1), events: &events)
    // The flour turns back to the near store, which fills before it lands.
    world.tick()
    world.stockpiles[near]?.deposit(.flour, amount: BuildingKind.warehouse.storagePerGood ?? 0)
    for _ in 0 ..< 80 where !world.carriers.isEmpty {
        world.tick()
    }
    #expect(world.carriers.isEmpty)
    #expect(world.stockpiles[far]?.quantity(of: .flour) == 1)
}

/// A lumberjack hut with 1 wood, a sawmill site waiting for wood, and a
/// warehouse beyond it.
private struct SiteTown {
    var world: World
    let site: EntityID
    let warehouse: EntityID
}

private func siteTown() -> SiteTown {
    var world = roadStrip()
    _ = inject(.lumberjackHut, in: &world, at: TileCoordinate(x: 1, y: 1), contents: [.wood: 1])
    let site = inject(.sawmill, in: &world, at: TileCoordinate(x: 6, y: 1))
    world.buildings[site]?.state = .constructing
    world.buildings[site]?.constructionState = .waitingForMaterials
    let warehouse = inject(.warehouse, in: &world, at: TileCoordinate(x: 14, y: 0))
    world.tick()
    return SiteTown(world: world, site: site, warehouse: warehouse)
}

@Test("scenario: goods for a site that no longer needs them go to storage")
func scenarioGoodsForASiteThatNoLongerNeedsThemGoToStorage() {
    let town = siteTown()
    var built = town.world
    let site = town.site, warehouse = town.warehouse
    let toSite = { (world: World) in
        world.carriers.values.contains { if case .deliverToConstructionSite = $0.mission { true } else { false } }
    }
    #expect(toSite(built))
    built.buildings[site]?.state = .operational
    for _ in 0 ..< 60 where toSite(built) {
        built.tick()
    }
    // The built sawmill's materials stay as they were; the wood heads to
    // the warehouse instead.
    #expect(built.buildings[site]?.materialsDelivered[.wood, default: 0] == 0)
    #expect(built.carriers.values.map(\.mission.destination) == [warehouse])

    let other = siteTown()
    var gone = other.world
    let goneWarehouse = other.warehouse
    var events: [WorldEvent] = []
    gone.applyDemolish(anchor: TileCoordinate(x: 6, y: 1), events: &events)
    for _ in 0 ..< 60 where !gone.carriers.isEmpty {
        gone.tick()
    }
    #expect(gone.stockpiles[goneWarehouse]?.quantity(of: .wood) == 1)
}
