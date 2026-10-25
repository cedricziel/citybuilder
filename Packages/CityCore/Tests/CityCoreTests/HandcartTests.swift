import Foundation
import Testing
@testable import CityCore

// warehouses-and-logistics / Handcarts carry long and bulk hauls
// (openspec/changes/visible-distribution, milestone 3).

private func inject(
    _ kind: BuildingKind, in world: inout World, at anchor: TileCoordinate, contents: [Good: Int] = [:]
) -> EntityID {
    let id = EntityID(raw: world.nextEntityRaw)
    world.nextEntityRaw &+= 1
    world.buildings[id] = Building(id: id, kind: kind, anchor: anchor, state: .operational, ticksSincePlacement: 0)
    for tile in BuildingCatalog.spec(for: kind).footprint.tiles(anchor: anchor) {
        world.occupiedTiles[tile] = id
    }
    var stockpile = Stockpile(capacity: 200)
    for (good, amount) in contents {
        _ = stockpile.deposit(good, amount: amount)
    }
    world.stockpiles[id] = stockpile
    return id
}

/// A grass strip with a road along y = 3. A 2×2 building at x reaches the
/// road at x; a 3×3 buffer at x reaches it at x too.
private func roadStrip(width: Int = 30) -> World {
    var world = World.fixtureWithTerrain(width: width, height: 6, fill: .grass, seed: 1)
    world.testMaterialCredits = [:]
    for x in 0 ..< width {
        world.roadGraph.addRoad(at: TileCoordinate(x: x, y: 3))
    }
    return world
}

private func departures(in world: World) -> [(Carrier.Mission, Vehicle?)] {
    world.carriers.values.sorted { $0.id.raw < $1.id.raw }.map { ($0.mission, $0.vehicle) }
}

@Test("scenario: a long haul with enough ready goes by handcart")
func scenarioALongHaulWithEnoughReadyGoesByHandcart() throws {
    var world = roadStrip()
    let hut = inject(.lumberjackHut, in: &world, at: TileCoordinate(x: 1, y: 1), contents: [.wood: 4])
    let warehouse = inject(.warehouse, in: &world, at: TileCoordinate(x: 16, y: 0))
    world.tick()
    let (mission, vehicle) = try #require(departures(in: world).first)
    #expect(mission == .deliver(good: .wood, amount: 4, fromProducer: hut, toWarehouse: warehouse))
    #expect(vehicle == .handcart)
    #expect(world.stockpiles[hut]?.quantity(of: .wood) == 0)
}

@Test("scenario: a short haul stays on foot")
func scenarioAShortHaulStaysOnFoot() throws {
    var world = roadStrip()
    let hut = inject(.lumberjackHut, in: &world, at: TileCoordinate(x: 1, y: 1), contents: [.wood: 4])
    let warehouse = inject(.warehouse, in: &world, at: TileCoordinate(x: 6, y: 0))
    world.tick()
    let (mission, vehicle) = try #require(departures(in: world).first)
    #expect(mission == .deliver(good: .wood, amount: 1, fromProducer: hut, toWarehouse: warehouse))
    #expect(vehicle == nil)
}

@Test("scenario: a long haul to storage waits for a cart load")
func scenarioALongHaulToStorageWaitsForACartLoad() throws {
    var world = roadStrip()
    let hut = inject(.lumberjackHut, in: &world, at: TileCoordinate(x: 1, y: 1), contents: [.wood: 2])
    let warehouse = inject(.warehouse, in: &world, at: TileCoordinate(x: 16, y: 0))
    world.tick()
    #expect(world.carriers.isEmpty)
    _ = world.stockpiles[hut]?.deposit(.wood, amount: 1)
    world.tick()
    let (mission, vehicle) = try #require(departures(in: world).first)
    #expect(mission == .deliver(good: .wood, amount: 3, fromProducer: hut, toWarehouse: warehouse))
    #expect(vehicle == .handcart)
}

@Test("a handcart takes no more than the buffer has room for")
func aHandcartTakesNoMoreThanTheBufferHasRoomFor() throws {
    var world = roadStrip()
    let hut = inject(.lumberjackHut, in: &world, at: TileCoordinate(x: 1, y: 1), contents: [.wood: 4])
    let warehouse = inject(.warehouse, in: &world, at: TileCoordinate(x: 16, y: 0))
    world.stockpiles[warehouse] = Stockpile(capacity: 3)
    world.tick()
    let (mission, vehicle) = try #require(departures(in: world).first)
    #expect(mission == .deliver(good: .wood, amount: 3, fromProducer: hut, toWarehouse: warehouse))
    #expect(vehicle == .handcart)
}

@Test("scenario: a handcart brings only what a consumer is short of")
func scenarioAHandcartBringsOnlyWhatAConsumerIsShortOf() throws {
    var world = roadStrip()
    let warehouse = inject(.warehouse, in: &world, at: TileCoordinate(x: 1, y: 0), contents: [.wood: 10])
    let burner = inject(.charcoalBurner, in: &world, at: TileCoordinate(x: 16, y: 1), contents: [.wood: 1])
    world.tick()
    let retrievals = departures(in: world).filter { if case .retrieve = $0.0 { true } else { false } }
    #expect(retrievals.count == 1)
    let (mission, vehicle) = try #require(retrievals.first)
    #expect(mission == .retrieve(good: .wood, amount: 3, fromWarehouse: warehouse, toConsumer: burner))
    #expect(vehicle == .handcart)
}

@Test("scenario: a consumer short of little gets a walker")
func scenarioAConsumerShortOfLittleGetsAWalker() throws {
    var world = roadStrip()
    let warehouse = inject(.warehouse, in: &world, at: TileCoordinate(x: 1, y: 0), contents: [.wood: 10])
    let burner = inject(.charcoalBurner, in: &world, at: TileCoordinate(x: 16, y: 1), contents: [.wood: 2])
    world.tick()
    let (mission, vehicle) = try #require(departures(in: world).first)
    #expect(mission == .retrieve(good: .wood, amount: 1, fromWarehouse: warehouse, toConsumer: burner))
    #expect(vehicle == nil)
}

@Test("scenario: a handcart counts as one of the producer's carriers")
func scenarioAHandcartCountsAsOneOfTheProducersCarriers() {
    var world = roadStrip()
    let hut = inject(.lumberjackHut, in: &world, at: TileCoordinate(x: 1, y: 1), contents: [.wood: 9])
    _ = inject(.warehouse, in: &world, at: TileCoordinate(x: 16, y: 0))
    world.tick()
    world.tick()
    world.tick()
    #expect(world.carrierCountByProducer[hut] == CarrierConfig.perProducerCap)
    #expect(world.carriers.count == CarrierConfig.perProducerCap)
}

@Test("a handcart unloads everything it carries")
func aHandcartUnloadsEverythingItCarries() {
    var world = roadStrip()
    let hut = inject(.lumberjackHut, in: &world, at: TileCoordinate(x: 1, y: 1), contents: [.wood: 4])
    let warehouse = inject(.warehouse, in: &world, at: TileCoordinate(x: 16, y: 0))
    for _ in 0 ..< 30 where world.stockpiles[warehouse]?.quantity(of: .wood) != 4 {
        world.tick()
    }
    #expect(world.stockpiles[warehouse]?.quantity(of: .wood) == 4)
    #expect(world.carrierCountByProducer[hut] == 0)
}

@Test("a carrier saved without a vehicle loads on foot")
func aCarrierSavedWithoutAVehicleLoadsOnFoot() throws {
    let carrier = Carrier(
        id: EntityID(raw: 5), path: [TileCoordinate(x: 0, y: 0), TileCoordinate(x: 1, y: 0)],
        mission: .deliver(good: .wood, amount: 1, fromProducer: EntityID(raw: 1), toWarehouse: EntityID(raw: 2)),
        vehicle: .handcart
    )
    var json = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(carrier)) as? [String: Any])
    #expect(json["vehicle"] as? String == "handcart")
    json.removeValue(forKey: "vehicle")
    let old = try JSONDecoder().decode(Carrier.self, from: JSONSerialization.data(withJSONObject: json))
    #expect(old.vehicle == nil)
    #expect(try JSONDecoder().decode(Carrier.self, from: JSONEncoder().encode(carrier)) == carrier)
}

@Test("the determinism fixture's long haul goes by handcart")
func theDeterminismFixturesLongHaulGoesByHandcart() {
    var world = World.haulFixture()
    var carts = 0
    var seen = Set<EntityID>()
    for _ in 0 ..< 1500 {
        world.tick()
        for carrier in world.carriers.values where carrier.vehicle == .handcart && seen.insert(carrier.id).inserted {
            carts += 1
        }
    }
    #expect(carts > 0)
}

@Test("scenario: goods that wait too long for a cart load go anyway")
func scenarioGoodsThatWaitTooLongForACartLoadGoAnyway() throws {
    var world = roadStrip()
    let hut = inject(.lumberjackHut, in: &world, at: TileCoordinate(x: 1, y: 1), contents: [.wood: 2])
    let warehouse = inject(.warehouse, in: &world, at: TileCoordinate(x: 16, y: 0))
    // The hut's catchment holds no forest, so no third log is coming.
    for _ in 0 ..< CarrierConfig.haulMaxWait {
        world.tick()
    }
    #expect(world.carriers.isEmpty)
    #expect(world.buildings[hut]?.haulWaitTicks == UInt32(CarrierConfig.haulMaxWait))
    world.tick()
    let (mission, vehicle) = try #require(departures(in: world).first)
    #expect(mission == .deliver(good: .wood, amount: 2, fromProducer: hut, toWarehouse: warehouse))
    #expect(vehicle == .handcart)
    #expect(world.buildings[hut]?.haulWaitTicks == 0)
}

@Test("a producer saved without a cart wait loads with none")
func aProducerSavedWithoutACartWaitLoadsWithNone() throws {
    var building = Building(id: EntityID(raw: 3), kind: .sawmill, anchor: TileCoordinate(x: 1, y: 1), state: .operational)
    building.haulWaitTicks = 7
    var json = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(building)) as? [String: Any])
    #expect(json["haulWaitTicks"] as? Int == 7)
    json.removeValue(forKey: "haulWaitTicks")
    let old = try JSONDecoder().decode(Building.self, from: JSONSerialization.data(withJSONObject: json))
    #expect(old.haulWaitTicks == 0)
}

@Test("a producer near storage on the grid but far by road waits for a cart load")
func aProducerNearStorageOnTheGridButFarByRoadWaitsForACartLoad() {
    var world = World.fixtureWithTerrain(width: 14, height: 10, fill: .grass, seed: 1)
    world.testMaterialCredits = [:]
    // A U-shaped road: out along y = 3, down x = 12, back along y = 6.
    for x in 0 ... 12 {
        world.roadGraph.addRoad(at: TileCoordinate(x: x, y: 3))
        world.roadGraph.addRoad(at: TileCoordinate(x: x, y: 6))
    }
    for y in 4 ... 5 {
        world.roadGraph.addRoad(at: TileCoordinate(x: 12, y: y))
    }
    let hut = inject(.lumberjackHut, in: &world, at: TileCoordinate(x: 1, y: 1), contents: [.wood: 2])
    _ = inject(.warehouse, in: &world, at: TileCoordinate(x: 1, y: 7))
    world.tick()
    #expect(world.carriers.isEmpty)
    #expect(world.buildings[hut]?.haulWaitTicks == 1)
}

@Test("the vehicle follows the owner's age")
func theVehicleFollowsTheOwnersAge() throws {
    #expect(CarrierConfig.vehicle(in: .antiquity) == nil)
    #expect(CarrierConfig.vehicle(in: .medieval) == .handcart)
    #expect(CarrierConfig.vehicle(in: .modern) == Vehicle.allCases.max { $0.age < $1.age })
    var world = roadStrip()
    world.age = .antiquity
    let hut = inject(.lumberjackHut, in: &world, at: TileCoordinate(x: 1, y: 1), contents: [.wood: 4])
    let warehouse = inject(.warehouse, in: &world, at: TileCoordinate(x: 16, y: 0))
    world.tick()
    let (mission, vehicle) = try #require(departures(in: world).first)
    #expect(mission == .deliver(good: .wood, amount: 1, fromProducer: hut, toWarehouse: warehouse))
    #expect(vehicle == nil)
    #expect(world.buildings[hut]?.haulWaitTicks == 0)
}

@Test("scenario: a long hop to a short consumer goes by handcart")
func scenarioALongHopToAShortConsumerGoesByHandcart() throws {
    var world = roadStrip()
    let farm = inject(.grainFarm, in: &world, at: TileCoordinate(x: 1, y: 1), contents: [.grain: 4])
    let windmill = inject(.windmill, in: &world, at: TileCoordinate(x: 16, y: 1))
    world.tick()
    let (mission, vehicle) = try #require(departures(in: world).first)
    #expect(mission == .deliverToConsumer(good: .grain, amount: 4, fromProducer: farm, toConsumer: windmill))
    #expect(vehicle == .handcart)
}

@Test("a long hop with too little ready walks one unit without waiting")
func aLongHopWithTooLittleReadyWalksOneUnitWithoutWaiting() throws {
    var world = roadStrip()
    let farm = inject(.grainFarm, in: &world, at: TileCoordinate(x: 1, y: 1), contents: [.grain: 2])
    let windmill = inject(.windmill, in: &world, at: TileCoordinate(x: 16, y: 1))
    world.tick()
    let (mission, vehicle) = try #require(departures(in: world).first)
    #expect(mission == .deliverToConsumer(good: .grain, amount: 1, fromProducer: farm, toConsumer: windmill))
    #expect(vehicle == nil)
}
