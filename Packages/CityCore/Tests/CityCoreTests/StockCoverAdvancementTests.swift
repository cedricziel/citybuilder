import Foundation
import Testing
@testable import CityCore

// population-and-needs / Advancing needs stock for two draws
// (openspec/changes/stock-cover-advancement).

/// A road along y = 4 from x = 0 to 12 and a warehouse at its west end holding plenty of every
/// merchant need but tools, and `tools` tools.
private func town(tools: Int) -> (World, store: EntityID) {
    var world = SignatureFixture.grass()
    let store = SignatureFixture.inject(.warehouse, at: TileCoordinate(x: 0, y: 1), in: &world)
    stock(store, tools: tools, in: &world)
    road(fromX: 0, toX: 12, in: &world)
    return (world, store)
}

private func stock(_ store: EntityID, tools: Int, in world: inout World) {
    for good in HouseTier.merchants.needs(in: world.culture) where good != .tools {
        world.stockpiles[store]?.deposit(good, amount: 30)
    }
    world.stockpiles[store]?.deposit(.tools, amount: tools)
}

private func road(fromX: Int, toX: Int, in world: inout World) {
    for x in fromX ... toX {
        world.roadGraph.addRoad(at: TileCoordinate(x: x, y: 4))
    }
}

/// A full citizen house at `x`, `ticks` ticks into its count towards advancing.
private func citizens(at x: Int, in world: inout World, counted ticks: UInt64 = 0) -> EntityID {
    let house = SignatureFixture.inject(.house, at: TileCoordinate(x: x, y: 2), in: &world)
    var population = HousePopulation()
    population.tier = .citizens
    population.population = 6
    population.ticksAtTierCondition = ticks
    world.populations[house] = population
    return house
}

private let advanceTicks = Int(HousePopulation.tierChangeTicks) + 5

@Test("scenario: one unit in reach is not enough to advance")
func scenarioOneUnitInReachIsNotEnoughToAdvance() {
    var (world, _) = town(tools: 1)
    let house = citizens(at: 6, in: &world)
    _ = SignatureFixture.run(&world, ticks: advanceTicks)
    #expect(world.populations[house]?.tier == .citizens)
}

@Test("scenario: stock for two draws lets a house advance")
func scenarioStockForTwoDrawsLetsAHouseAdvance() {
    var (world, _) = town(tools: 2)
    let house = citizens(at: 6, in: &world)
    _ = SignatureFixture.run(&world, ticks: advanceTicks)
    #expect(world.populations[house]?.tier == .merchants)
}

@Test("scenario: houses advancing in the same tick share the stock")
func scenarioHousesAdvancingInTheSameTickShareTheStock() {
    var (world, _) = town(tools: 3)
    let first = citizens(at: 6, in: &world)
    let second = citizens(at: 9, in: &world)
    _ = SignatureFixture.run(&world, ticks: advanceTicks)
    #expect(world.populations[first]?.tier == .merchants)
    #expect(world.populations[second]?.tier == .citizens)
    #expect(world.populations[second]?.ticksAtTierCondition ?? .max < UInt64(advanceTicks))
}

@Test("scenario: claims last one tick")
func scenarioClaimsLastOneTick() {
    var (world, _) = town(tools: 2)
    // The house visited second advances a tick before the one visited first, so its claim is
    // made after the other house's check that tick and has gone by the next.
    let later = citizens(at: 6, in: &world)
    let earlier = citizens(at: 9, in: &world, counted: 1)
    _ = SignatureFixture.run(&world, ticks: advanceTicks)
    #expect(world.populations[earlier]?.tier == .merchants)
    #expect(world.populations[later]?.tier == .merchants)
}

@Test("scenario: a need the house already has needs one unit")
func scenarioANeedTheHouseAlreadyHasNeedsOneUnit() {
    var (world, store) = town(tools: 2)
    // Citizens eat a plank at the consumption inside the 120 ticks, leaving 1.
    let planks = world.stockpiles[store]?.quantity(of: .planks) ?? 0
    world.stockpiles[store]?.withdraw(.planks, amount: planks - 2)
    let house = citizens(at: 6, in: &world)
    _ = SignatureFixture.run(&world, ticks: advanceTicks)
    #expect(world.stockpiles[store]?.quantity(of: .planks) == 1)
    #expect(world.populations[house]?.tier == .merchants)
}

@Test("scenario: houses on separate road networks do not share claims")
func scenarioHousesOnSeparateRoadNetworksDoNotShareClaims() {
    var (world, _) = town(tools: 2)
    let west = citizens(at: 6, in: &world)
    let eastStore = SignatureFixture.inject(.warehouse, at: TileCoordinate(x: 20, y: 1), in: &world)
    stock(eastStore, tools: 2, in: &world)
    road(fromX: 20, toX: 30, in: &world)
    let east = citizens(at: 25, in: &world)
    _ = SignatureFixture.run(&world, ticks: advanceTicks)
    #expect(world.populations[west]?.tier == .merchants)
    #expect(world.populations[east]?.tier == .merchants)
}
