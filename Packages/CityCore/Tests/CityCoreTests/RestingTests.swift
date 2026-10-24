import Testing
@testable import CityCore

// goods-and-production / Producers rest while the stores hold plenty, and
// warehouses-and-logistics / Buildings report why they are idle
// (openspec/changes/rest-when-stocked).

/// A warehouse holding `contents` and a `kind` producer on one road, after
/// the tick that lays the road and runs the first supply pass.
private func town(_ kind: BuildingKind, warehouse contents: [Good: Int], owner: Owner = .player) -> (World, EntityID) {
    var world = World.fixtureWithTerrain(width: 14, height: 6, fill: .grass, seed: 1)
    world.testMaterialCredits = [:]
    let producer = place(kind, at: TileCoordinate(x: 1, y: 1), owner: owner, in: &world)
    let store = place(.warehouse, at: TileCoordinate(x: 9, y: 0), owner: owner, in: &world)
    for (good, amount) in contents.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
        world.stockpiles[store]?.deposit(good, amount: amount)
    }
    for x in 0 ... 12 {
        world.enqueue(.place(.road, at: TileCoordinate(x: x, y: 3)))
    }
    world.tick()
    return (world, producer)
}

private func place(_ kind: BuildingKind, at anchor: TileCoordinate, owner: Owner, in world: inout World) -> EntityID {
    let id = EntityID(raw: world.nextEntityRaw)
    world.nextEntityRaw &+= 1
    world.buildings[id] = Building(id: id, kind: kind, anchor: anchor, state: .operational, owner: owner)
    for tile in BuildingCatalog.spec(for: kind).footprint.tiles(anchor: anchor) {
        world.occupiedTiles[tile] = id
    }
    world.stockpiles[id] = World.stockpileCapacity(for: kind).map { Stockpile(capacity: $0) }
    return id
}

private func woodCarriers(to consumer: EntityID, in world: World) -> Int {
    world.carriers.values.count { carrier in
        if case let .retrieve(good, _, _, toConsumer) = carrier.mission { return good == .wood && toConsumer == consumer }
        return false
    }
}

@Test("scenario: a sawmill rests on 40 planks")
func scenarioASawmillRestsOn40Planks() throws {
    let (world, sawmill) = town(.sawmill, warehouse: [.planks: 40, .wood: 20])
    #expect(try world.isResting(#require(world.buildings[sawmill])) == .planks)
    #expect(woodCarriers(to: sawmill, in: world) == 0)
}

@Test("scenario: a sawmill works below the rest level")
func scenarioASawmillWorksBelowTheRestLevel() throws {
    let (world, sawmill) = town(.sawmill, warehouse: [.planks: 39, .wood: 20])
    #expect(try world.isResting(#require(world.buildings[sawmill])) == nil)
    #expect(woodCarriers(to: sawmill, in: world) > 0)
}

/// Direct hops from a producer to a short consumer ask `needsSupply` too,
/// so the rest check there covers every route that feeds a producer.
@Test("no route offers a resting producer more input")
func noRouteOffersARestingProducerMoreInput() {
    let (resting, sawmill) = town(.sawmill, warehouse: [.planks: 40])
    #expect(!resting.needsSupply(sawmill, good: .wood, amount: 1, stored: resting.storedTotals(of: .player)))
    let (working, other) = town(.sawmill, warehouse: [.planks: 39])
    #expect(working.needsSupply(other, good: .wood, amount: 1, stored: working.storedTotals(of: .player)))
}

@Test("scenario: a resting producer finishes its cycle")
func scenarioARestingProducerFinishesItsCycle() {
    var (world, sawmill) = town(.sawmill, warehouse: [.planks: 40])
    world.stockpiles[sawmill]?.deposit(.wood, amount: 1)
    var finished = false
    for _ in 0 ..< 40 where !finished {
        finished = world.tick().events.contains(.productionCycleCompleted(producer: sawmill, kind: .sawmill))
    }
    #expect(finished)
}

@Test("scenario: gatherers never rest")
func scenarioGatherersNeverRest() throws {
    let (world, hut) = town(.lumberjackHut, warehouse: [.wood: 40, .planks: 40])
    #expect(try world.isResting(#require(world.buildings[hut])) == nil)
}

@Test("a rival's producer rests on the rival's stores")
func rivalProducerRestsOnRivalStores() throws {
    let (world, sawmill) = town(.sawmill, warehouse: [.planks: 40, .wood: 20], owner: .rival(RivalID(1)))
    #expect(try world.isResting(#require(world.buildings[sawmill])) == .planks)
    #expect(woodCarriers(to: sawmill, in: world) == 0)
}

@Test("scenario: a resting producer reports resting")
func scenarioARestingProducerReportsResting() {
    let (world, sawmill) = town(.sawmill, warehouse: [.planks: 40])
    #expect(world.buildingIssues()[sawmill] == .resting(.planks))
}
