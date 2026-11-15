import Foundation
import Testing
@testable import CityCore

// Scenarios from openspec/changes/fix-merchant-churn (population-and-needs /
// Houses move up one at a time per hub).

/// A town center and `count` houses on one road, all served by it, each
/// set to `residents` of `tier`, with the hub holding 40 of every need.
private struct Street {
    var world: World
    let houses: [EntityID]
}

private func street(houses count: Int, tier: HouseTier, residents: UInt32) throws -> Street {
    var world = World.fixtureWithTerrain(width: 2 * count + 8, height: 8, fill: .grass, seed: 1)
    world.testMaterialCredits = [:]
    world.economy.credit(100_000)
    let hubAnchor = TileCoordinate(x: 2 * count + 2, y: 0)
    let hub = SignatureFixture.inject(.townCenter, at: hubAnchor, in: &world)
    var materials = Stockpile(capacity: 400)
    _ = materials.deposit(.wood, amount: 100)
    _ = materials.deposit(.planks, amount: 100)
    world.stockpiles[hub] = materials
    for index in 0 ..< count {
        world.enqueue(.place(.house, at: TileCoordinate(x: 2 * index, y: 1)))
    }
    for x in 0 ... 2 * count + 4 {
        world.enqueue(.place(.road, at: TileCoordinate(x: x, y: 3)))
    }
    world.tick()
    let houses = try (0 ..< count).map { try #require(world.occupiedTiles[TileCoordinate(x: 2 * $0, y: 1)]) }
    while houses.contains(where: { world.buildings[$0]?.state != .operational }) {
        world.tick()
    }
    var stock = Stockpile(capacity: 40)
    for good in Good.allCases {
        _ = stock.deposit(good, amount: 40)
    }
    world.stockpiles[hub] = stock
    for house in houses {
        var pop = HousePopulation()
        pop.tier = tier
        pop.population = residents
        for good in tier.needs(in: world.culture) {
            pop.addStock(good, amount: pop.stockCapacity(of: good))
        }
        world.populations[house] = pop
    }
    return Street(world: world, houses: houses)
}

private func count(_ tier: HouseTier, in world: World, _ houses: [EntityID]) -> Int {
    houses.filter { world.populations[$0]?.tier == tier }.count
}

@Test("scenario: a stocked hub moves one house up per interval")
func scenarioAStockedHubMovesOneHouseUpPerInterval() throws {
    var town = try street(houses: 6, tier: .citizens, residents: 6)
    for _ in 0 ..< 180 {
        town.world.tick()
    }
    #expect(count(.merchants, in: town.world, town.houses) == 1)
    for _ in 0 ..< 100 {
        town.world.tick()
    }
    #expect(count(.merchants, in: town.world, town.houses) == 2)
}

@Test("scenario: the oldest waiting house moves up first")
func scenarioTheOldestWaitingHouseMovesUpFirst() throws {
    var town = try street(houses: 3, tier: .citizens, residents: 6)
    for _ in 0 ..< 180 {
        town.world.tick()
    }
    #expect(town.world.populations[town.houses[0]]?.tier == .merchants)
    #expect(town.world.populations[town.houses[1]]?.tier == .citizens)
}

@Test("scenario: a waiting house moves up as soon as its turn comes")
func scenarioAWaitingHouseMovesUpAsSoonAsItsTurnComes() throws {
    var town = try street(houses: 2, tier: .citizens, residents: 6)
    var firstUp: UInt64?
    var secondUp: UInt64?
    for _ in 0 ..< 400 where secondUp == nil {
        town.world.tick()
        if firstUp == nil, town.world.populations[town.houses[0]]?.tier == .merchants { firstUp = town.world.tickCount }
        if town.world.populations[town.houses[1]]?.tier == .merchants { secondUp = town.world.tickCount }
    }
    let first = try #require(firstUp)
    let second = try #require(secondUp)
    #expect(second - first == HousePopulation.advanceSpacingTicks)
}

@Test("scenario: a decline does not hold up the next advance")
func scenarioADeclineDoesNotHoldUpTheNextAdvance() throws {
    var town = try street(houses: 2, tier: .citizens, residents: 6)
    // The first house came down from merchants a moment ago.
    town.world.populations[town.houses[0]]?.ticksSinceAdvance = 0
    town.world.populations[town.houses[0]]?.tier = .citizens
    for _ in 0 ..< 125 {
        town.world.tick()
    }
    #expect(count(.merchants, in: town.world, town.houses) == 1)
}

@Test("advance spacing survives a save")
func advanceSpacingSurvivesASave() throws {
    var pop = HousePopulation()
    pop.ticksSinceAdvance = 42
    let decoded = try JSONDecoder().decode(HousePopulation.self, from: JSONEncoder().encode(pop))
    #expect(decoded.ticksSinceAdvance == 42)
    let older = Data(#"{"population":2}"#.utf8)
    #expect(try JSONDecoder().decode(HousePopulation.self, from: older).ticksSinceAdvance >= HousePopulation.advanceSpacingTicks)
}
