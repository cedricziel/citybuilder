import Foundation
import Testing
@testable import CityCore

// population-and-needs / Advancing needs stock for two draws
// (openspec/changes/stock-cover-advancement).

/// A grass strip with roads along y = 3 over each of `roads`. A town center at (x, 0) serves the
/// houses on its own road.
private func strip(roads: [ClosedRange<Int>] = [0 ... 43]) -> World {
    var world = World.fixtureWithTerrain(width: 44, height: 9, fill: .grass, seed: 1)
    for range in roads {
        for x in range {
            let tile = TileCoordinate(x: x, y: 3)
            SignatureFixture.inject(.road, at: tile, in: &world)
            world.roadGraph.addRoad(at: tile)
        }
    }
    return world
}

/// A town center at `x` holding plenty of every merchant need but tools, and `tools` tools.
private func hub(at x: Int = 0, tools: Int, in world: inout World) -> EntityID {
    let id = addOperational(.townCenter, at: TileCoordinate(x: x, y: 0), in: &world)
    for good in HouseTier.merchants.needs(in: world.culture) where good != .tools {
        world.stockpiles[id]?.deposit(good, amount: 30)
    }
    world.stockpiles[id]?.deposit(.tools, amount: tools)
    return id
}

/// A full citizen house at `x` with its food and planks met, `ticks` ticks into its count towards
/// advancing.
private func citizens(at x: Int, in world: inout World, counted ticks: UInt64 = 0) -> EntityID {
    let id = addOperational(.house, at: TileCoordinate(x: x, y: 4), residents: 6, in: &world)
    world.populations[id]?.tier = .citizens
    world.populations[id]?.addStock(.food, amount: 6)
    world.populations[id]?.addStock(.planks, amount: 2)
    world.populations[id]?.ticksAtTierCondition = ticks
    return id
}

private func run(_ world: inout World, ticks: Int = Int(HousePopulation.tierChangeTicks) + 10) {
    for _ in 0 ..< ticks {
        _ = world.tick()
    }
}

@Test("scenario: one unit at the hub is not enough to advance")
func scenarioOneUnitAtTheHubIsNotEnoughToAdvance() {
    var world = strip()
    _ = hub(tools: 1, in: &world)
    let house = citizens(at: 6, in: &world)
    run(&world)
    #expect(world.populations[house]?.tier == .citizens)
}

@Test("scenario: stock for two draws lets a house advance")
func scenarioStockForTwoDrawsLetsAHouseAdvance() {
    var world = strip()
    _ = hub(tools: 2, in: &world)
    let house = citizens(at: 6, in: &world)
    run(&world)
    #expect(world.populations[house]?.tier == .merchants)
}

@Test("scenario: houses advancing in the same tick share the hub's stock")
func scenarioHousesAdvancingInTheSameTickShareTheHubsStock() {
    var world = strip()
    _ = hub(tools: 3, in: &world)
    let first = citizens(at: 6, in: &world)
    let second = citizens(at: 9, in: &world)
    run(&world)
    #expect(world.populations[first]?.tier == .merchants)
    #expect(world.populations[second]?.tier == .citizens)
    #expect(world.populations[second]?.ticksAtTierCondition ?? .max < HousePopulation.tierChangeTicks)
}

@Test("scenario: claims last one tick")
func scenarioClaimsLastOneTick() {
    var world = strip()
    _ = hub(tools: 2, in: &world)
    // The house visited second advances a tick before the one visited first, so its claim is
    // made after the other house's check that tick and has gone by the next.
    let later = citizens(at: 6, in: &world)
    let earlier = citizens(at: 9, in: &world, counted: 1)
    run(&world)
    #expect(world.populations[earlier]?.tier == .merchants)
    #expect(world.populations[later]?.tier == .merchants)
}

@Test("scenario: houses served by different hubs do not share claims")
func scenarioHousesServedByDifferentHubsDoNotShareClaims() {
    var world = strip(roads: [0 ... 18, 24 ... 43])
    _ = hub(tools: 2, in: &world)
    _ = hub(at: 24, tools: 2, in: &world)
    let west = citizens(at: 6, in: &world)
    let east = citizens(at: 30, in: &world)
    #expect(world.hubService().hubOf[west]?.hub != world.hubService().hubOf[east]?.hub)
    run(&world)
    #expect(world.populations[west]?.tier == .merchants)
    #expect(world.populations[east]?.tier == .merchants)
}
