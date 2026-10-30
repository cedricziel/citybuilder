import Foundation
import Testing
@testable import CityCore

// Which house a porter goes to (openspec/changes/visible-distribution,
// population-and-needs / Market porters supply houses).

private func strip() -> World {
    var world = World.fixtureWithTerrain(width: 44, height: 9, fill: .grass, seed: 1)
    for x in 0 ... 43 {
        let tile = TileCoordinate(x: x, y: 3)
        SignatureFixture.inject(.road, at: tile, in: &world)
        world.roadGraph.addRoad(at: tile)
    }
    return world
}

private func house(at x: Int, residents: UInt32 = 4, tier: HouseTier = .peasants, in world: inout World) -> EntityID {
    let id = addOperational(.house, at: TileCoordinate(x: x, y: 4), residents: residents, in: &world)
    world.populations[id]?.tier = tier
    return id
}

private func stock(_ id: EntityID, _ goods: [Good: Int], in world: inout World) {
    for (good, units) in goods.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
        world.populations[id]?.addStock(good, amount: units)
    }
}

private func fill(_ id: EntityID, _ goods: [Good: Int], in world: inout World) {
    for (good, units) in goods {
        world.stockpiles[id]?.deposit(good, amount: units)
    }
}

private func run(_ world: inout World, ticks: Int) {
    for _ in 0 ..< ticks {
        _ = world.tick()
    }
}

private func center(in world: inout World) -> EntityID {
    addOperational(.townCenter, at: TileCoordinate(x: 0, y: 0), in: &world)
}

@Test("scenario: Porters go to the house that needs them most")
func portersGoToTheHouseThatNeedsThemMost() {
    // A rival's porters spread by stock ratio.
    var world = strip()
    let hub = SignatureFixture.inject(.townCenter, at: TileCoordinate(x: 0, y: 0), in: &world, owner: .rival(1))
    fill(hub, [.food: 10], in: &world)
    let half = rivalHouse(at: 6, in: &world)
    stock(half, [.food: 2], in: &world)
    let empty = rivalHouse(at: 12, in: &world)
    run(&world, ticks: 1)
    #expect(world.porters.map(\.house) == [empty])
}

@Test("scenario: The player's porters serve the oldest house of a tier first")
func thePlayersPortersServeTheOldestHouseFirst() {
    var world = strip()
    let hub = center(in: &world)
    fill(hub, [.food: 10], in: &world)
    let older = house(at: 6, in: &world)
    stock(older, [.food: 2], in: &world)
    _ = house(at: 12, in: &world)
    run(&world, ticks: 1)
    #expect(world.porters.map(\.house) == [older])
}

@Test func equalNeedGoesToTheNearerHouse() {
    // A rival's porters break a tie in stock ratio by the shorter road.
    var world = strip()
    let hub = SignatureFixture.inject(.townCenter, at: TileCoordinate(x: 0, y: 0), in: &world, owner: .rival(1))
    fill(hub, [.food: 10], in: &world)
    _ = rivalHouse(at: 12, in: &world)
    let near = rivalHouse(at: 6, in: &world)
    run(&world, ticks: 1)
    #expect(world.porters.map(\.house) == [near])
}

@Test("scenario: Porters serve the higher tier first")
func portersServeTheHigherTierFirst() {
    var world = strip()
    let hub = center(in: &world)
    fill(hub, [.food: 10, .planks: 10], in: &world)
    _ = house(at: 6, in: &world)
    let citizens = house(at: 12, tier: .citizens, in: &world)
    stock(citizens, [.food: 3, .planks: 1], in: &world)
    run(&world, ticks: 1)
    #expect(world.porters.map(\.house) == [citizens])
}

@Test("scenario: A rival's porters go by stock ratio alone")
func aRivalsPortersGoByStockRatioAlone() {
    var world = strip()
    let hub = SignatureFixture.inject(.townCenter, at: TileCoordinate(x: 0, y: 0), in: &world, owner: .rival(1))
    fill(hub, [.food: 10, .planks: 10], in: &world)
    let peasants = SignatureFixture.inject(.house, at: TileCoordinate(x: 6, y: 4), in: &world, owner: .rival(1))
    var pop = HousePopulation()
    pop.population = 4
    world.populations[peasants] = pop
    let citizens = SignatureFixture.inject(.house, at: TileCoordinate(x: 12, y: 4), in: &world, owner: .rival(1))
    pop.tier = .citizens
    world.populations[citizens] = pop
    stock(citizens, [.food: 3, .planks: 1], in: &world)
    run(&world, ticks: 1)
    #expect(world.porters.map(\.house) == [peasants])
}

private func rivalHouse(at x: Int, in world: inout World) -> EntityID {
    let id = SignatureFixture.inject(.house, at: TileCoordinate(x: x, y: 4), in: &world, owner: .rival(1))
    var pop = HousePopulation()
    pop.population = 4
    world.populations[id] = pop
    return id
}
