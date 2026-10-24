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

private func departures(in world: World) -> [(Carrier.Mission, Carrier.Vehicle)] {
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
    #expect(vehicle == .onFoot)
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
    #expect(vehicle == .onFoot)
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
    #expect(old.vehicle == .onFoot)
    #expect(try JSONDecoder().decode(Carrier.self, from: JSONEncoder().encode(carrier)) == carrier)
}
