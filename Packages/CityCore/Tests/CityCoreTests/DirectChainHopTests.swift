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
    var stockpile = Stockpile(capacity: 200)
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
    #expect(world.supplyCarrierCount(to: bakery, good: .flour) == 1)
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
