import Foundation
import Testing
@testable import CityCore

// Scenarios from openspec/changes/add-age-signatures: workshops, speed
// bonuses and fuel (milestone M2).

private typealias Fixture = SignatureFixture

private let origin = TileCoordinate(x: 2, y: 2)

/// A sawmill `gap` tiles east of a building anchored at `origin` with
/// footprint width `width`.
private func east(of width: Int, gap: Int) -> TileCoordinate {
    TileCoordinate(x: origin.x + width - 1 + gap, y: origin.y)
}

@Test("scenario: sawmill near a guild hall")
func scenarioSawmillNearAGuildHall() {
    var world = Fixture.grass()
    Fixture.inject(.guildHall, at: origin, in: &world)
    let sawmill = Fixture.suppliedSawmill(at: east(of: 3, gap: 3), in: &world)
    #expect(Fixture.cycleTicks(of: sawmill, in: &world) == 20)
}

@Test("scenario: two guild halls count once")
func scenarioTwoGuildHallsCountOnce() {
    var world = Fixture.grass()
    Fixture.inject(.guildHall, at: origin, in: &world)
    Fixture.inject(.guildHall, at: TileCoordinate(x: 2, y: 8), in: &world)
    let sawmill = Fixture.suppliedSawmill(at: east(of: 3, gap: 2), in: &world)
    #expect(Fixture.cycleTicks(of: sawmill, in: &world) == 20)
}

@Test("scenario: farms are not workshops")
func scenarioFarmsAreNotWorkshops() {
    var world = Fixture.grass()
    Fixture.inject(.guildHall, at: origin, in: &world)
    let farm = Fixture.inject(.farm, at: east(of: 3, gap: 2), in: &world)
    #expect(Fixture.cycleTicks(of: farm, in: &world) == 40)
}

@Test("a constructing guild hall speeds up nothing")
func constructingGuildHallHasNoEffect() {
    var world = Fixture.grass()
    Fixture.inject(.guildHall, at: origin, in: &world, state: .constructing)
    world.buildings.values.filter { $0.kind == .guildHall }.forEach { world.buildings[$0.id]?.constructionState = .waitingForMaterials }
    let sawmill = Fixture.suppliedSawmill(at: east(of: 3, gap: 3), in: &world)
    #expect(Fixture.cycleTicks(of: sawmill, in: &world) == 25)
}

@Test("scenario: guild hall after printing press")
func scenarioGuildHallAfterPrintingPress() {
    var world = Fixture.grass()
    world.research = World.initialResearch(for: .medieval)
    var merchants = HousePopulation()
    merchants.tier = .merchants
    merchants.population = 20
    world.populations[EntityID(raw: 9999)] = merchants
    Fixture.inject(.guildHall, at: origin, in: &world)
    let sawmill = Fixture.suppliedSawmill(at: east(of: 3, gap: 3), in: &world)
    world.enqueue(.chooseResearch(.printingPress))
    world.tick()
    world.research.knowledge += Tech.printingPress.cost
    world.tick()
    #expect(world.age == .renaissance)
    #expect(Fixture.cycleTicks(of: sawmill, in: &world) == 20)
}

@Test("scenario: steam doubles a sawmill")
func scenarioSteamDoublesASawmill() {
    var world = Fixture.grass()
    Fixture.fuelled(.steamEngine, at: origin, in: &world)
    let sawmill = Fixture.suppliedSawmill(at: east(of: 2, gap: 5), in: &world)
    #expect(Fixture.cycleTicks(of: sawmill, in: &world) == 13)
}

@Test("an unfuelled steam engine speeds up nothing")
func coldEngineDoesNotSpeedUpWorkshops() {
    var world = Fixture.grass()
    Fixture.inject(.steamEngine, at: origin, in: &world)
    let sawmill = Fixture.suppliedSawmill(at: east(of: 2, gap: 5), in: &world)
    #expect(Fixture.cycleTicks(of: sawmill, in: &world) == 25)
}

@Test("scenario: power plant speeds a sawmill")
func scenarioPowerPlantSpeedsASawmill() {
    var world = Fixture.grass()
    Fixture.fuelled(.powerPlant, at: origin, in: &world)
    let sawmill = Fixture.suppliedSawmill(at: east(of: 3, gap: 8), in: &world)
    #expect(Fixture.cycleTicks(of: sawmill, in: &world) == 17)
}

@Test("scenario: steam and electricity")
func scenarioSteamAndElectricity() {
    var world = Fixture.grass()
    Fixture.fuelled(.powerPlant, at: origin, in: &world)
    Fixture.fuelled(.steamEngine, at: TileCoordinate(x: 2, y: 8), in: &world)
    let sawmill = Fixture.suppliedSawmill(at: east(of: 3, gap: 4), in: &world)
    #expect(Fixture.cycleTicks(of: sawmill, in: &world) == 10)
}

@Test("scenario: faster sawmill keeps its recipe")
func scenarioFasterSawmillKeepsItsRecipe() {
    var world = Fixture.grass()
    Fixture.fuelled(.steamEngine, at: origin, in: &world)
    let sawmill = Fixture.inject(.sawmill, at: east(of: 2, gap: 1), in: &world)
    world.stockpiles[sawmill]?.deposit(.wood, amount: 1)
    #expect(Fixture.cycleTicks(of: sawmill, in: &world) == 13)
    #expect(world.stockpiles[sawmill]?.quantity(of: .wood) == 0)
    #expect(world.stockpiles[sawmill]?.quantity(of: .planks) == 1)
}

@Test("scenario: stalled workshop gains nothing")
func scenarioStalledWorkshopGainsNothing() {
    var world = Fixture.grass()
    Fixture.fuelled(.steamEngine, at: origin, in: &world)
    let sawmill = Fixture.inject(.sawmill, at: east(of: 2, gap: 1), in: &world)
    _ = Fixture.run(&world, ticks: 30)
    #expect(world.productions[sawmill]?.ticksThisCycle == 0)
}

// MARK: - Fuel

@Test("scenario: engine burns charcoal")
func scenarioEngineBurnsCharcoal() {
    var world = Fixture.grass()
    let engine = Fixture.inject(.steamEngine, at: origin, in: &world)
    Fixture.runUntilBefore(multipleOf: 50, in: &world)
    world.stockpiles[engine]?.deposit(.charcoal, amount: 2)
    world.tick()
    #expect(world.stockpiles[engine]?.quantity(of: .charcoal) == 1)
    #expect(world.buildings[engine]?.fuelled == true)
}

@Test("scenario: engine runs out")
func scenarioEngineRunsOut() {
    var world = Fixture.grass()
    let engine = Fixture.inject(.steamEngine, at: origin, in: &world)
    world.buildings[engine]?.fuelled = true
    Fixture.runUntilBefore(multipleOf: 50, in: &world)
    #expect(world.buildings[engine]?.fuelled == true)
    let events = world.tick().events
    #expect(world.buildings[engine]?.fuelled == false)
    #expect(events.contains(.fuelRanOut(building: engine, kind: .steamEngine)))
    Fixture.runUntilBefore(multipleOf: 50, in: &world)
    #expect(!world.tick().events.contains(.fuelRanOut(building: engine, kind: .steamEngine)))
}

@Test("scenario: power plant needs two")
func scenarioPowerPlantNeedsTwo() {
    var world = Fixture.grass()
    let plant = Fixture.inject(.powerPlant, at: origin, in: &world)
    Fixture.runUntilBefore(multipleOf: 50, in: &world)
    world.stockpiles[plant]?.deposit(.charcoal, amount: 1)
    world.tick()
    #expect(world.stockpiles[plant]?.quantity(of: .charcoal) == 1)
    #expect(world.buildings[plant]?.fuelled == false)
}

@Test("fuel specs follow the design")
func fuelSpecs() {
    #expect(BuildingKind.steamEngine.fuel == FuelSpec(good: .charcoal, amount: 1, intervalTicks: 50))
    #expect(BuildingKind.powerPlant.fuel == FuelSpec(good: .charcoal, amount: 2, intervalTicks: 50))
    #expect(BuildingKind.guildHall.fuel == nil)
}

@Test("supply carriers keep twice the burn amount of fuel on hand")
func supplyCarriersDeliverFuel() {
    var world = Fixture.grass()
    let warehouse = Fixture.inject(.warehouse, at: TileCoordinate(x: 0, y: 0), in: &world)
    world.stockpiles[warehouse]?.deposit(.charcoal, amount: 10)
    for x in 0 ... 10 {
        world.enqueue(.place(.road, at: TileCoordinate(x: x, y: 3)))
    }
    let plant = Fixture.inject(.powerPlant, at: TileCoordinate(x: 5, y: 4), in: &world)
    _ = Fixture.run(&world, ticks: 30)
    #expect(world.stockpiles[plant]?.quantity(of: .charcoal) == 4)
    #expect(world.stockpiles[warehouse]?.quantity(of: .charcoal) == 6)
}

// MARK: - Economy

@Test("scenario: cold power plant still costs upkeep")
func scenarioColdPowerPlantStillCostsUpkeep() {
    var world = Fixture.grass()
    Fixture.inject(.powerPlant, at: origin, in: &world)
    Fixture.runUntilBefore(multipleOf: Economy.upkeepIntervalTicks, in: &world)
    let before = world.economy.balance
    world.tick()
    #expect(world.economy.balance == before - 6)
}

// MARK: - Performance

@Test("signature sources keep the mean tick inside the 10 hz budget")
func signatureSourcesStayInsideTheTickBudget() {
    var world = Fixture.grass(width: 96, height: 64)
    for slot in 0 ..< 10 {
        Fixture.inject(.guildHall, at: TileCoordinate(x: 2 + slot * 9, y: 2), in: &world)
        Fixture.fuelled(.steamEngine, at: TileCoordinate(x: 2 + slot * 9, y: 20), in: &world)
    }
    for slot in 0 ..< 3 {
        Fixture.fuelled(.powerPlant, at: TileCoordinate(x: 10 + slot * 30, y: 40), in: &world)
    }
    for slot in 0 ..< 40 {
        _ = Fixture.suppliedSawmill(at: TileCoordinate(x: 2 + (slot % 20) * 4, y: 8 + (slot / 20) * 20), in: &world)
        Fixture.inject(.house, at: TileCoordinate(x: 2 + (slot % 20) * 4, y: 12 + (slot / 20) * 20), in: &world)
    }
    // The mean, not the slowest tick: the suite runs tests in parallel,
    // so a single tick can stall on a busy machine.
    var total: UInt64 = 0
    for _ in 0 ..< 100 {
        total += world.tick().metrics.wallClockNanoseconds
    }
    #expect(total / 100 < 100_000_000, "mean tick took \(total / 100) ns")
}
