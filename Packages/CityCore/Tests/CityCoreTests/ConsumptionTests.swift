import Foundation
import Testing
@testable import CityCore

// Scenarios from population-and-needs: Houses consume food and planks,
// and the tier requirements from openspec/changes/add-population-tiers.

private struct Fixture {
    var world: World
    let house: EntityID
    let center: EntityID
}

private func houseNextToTownCenter(
    food: Int, planks: Int, bread: Int = 0, tools: Int = 0, residents: UInt32, tier: HouseTier = .citizens
) throws -> Fixture {
    var world = World.fixtureWithTerrain(width: 12, height: 8, fill: .grass, seed: 1)
    world.testMaterialCredits = [:]
    let center = EntityID(raw: world.nextEntityRaw)
    world.nextEntityRaw &+= 1
    world.buildings[center] = Building(
        id: center, kind: .townCenter, anchor: TileCoordinate(x: 6, y: 0),
        state: .operational, ticksSincePlacement: 0
    )
    for tile in BuildingCatalog.spec(for: .townCenter).footprint.tiles(anchor: TileCoordinate(x: 6, y: 0)) {
        world.occupiedTiles[tile] = center
    }
    var building = Stockpile(capacity: 40)
    _ = building.deposit(.planks, amount: 4)
    world.stockpiles[center] = building
    world.economy.credit(10000)
    world.enqueue(.place(.house, at: TileCoordinate(x: 1, y: 1)))
    for x in 0 ... 10 {
        world.enqueue(.place(.road, at: TileCoordinate(x: x, y: 3)))
    }
    world.tick()
    let house = try #require(world.occupiedTiles[TileCoordinate(x: 1, y: 1)])
    let interval = HousePopulation.consumptionIntervalTicks
    while world.buildings[house]?.state != .operational || !(world.tickCount + 1).isMultiple(of: interval) {
        world.tick()
    }
    // Set stock and residents one tick before consumption, so neither
    // construction costs nor growth blur the measured amounts.
    var stock = Stockpile(capacity: 40)
    _ = stock.deposit(.food, amount: food)
    _ = stock.deposit(.planks, amount: planks)
    _ = stock.deposit(.bread, amount: bread)
    _ = stock.deposit(.tools, amount: tools)
    world.stockpiles[center] = stock
    var pop = HousePopulation()
    pop.tier = tier
    pop.population = residents
    world.populations[house] = pop
    return Fixture(world: world, house: house, center: center)
}

private func advanceToNextConsumption(_ world: inout World) {
    world.tick()
    #expect(world.tickCount.isMultiple(of: HousePopulation.consumptionIntervalTicks))
}

@Test("scenario: populated house eats food on the consumption interval")
func scenarioPopulatedHouseEatsFoodOnTheConsumptionInterval() throws {
    var fixture = try houseNextToTownCenter(food: 10, planks: 10, residents: 4)
    advanceToNextConsumption(&fixture.world)
    #expect(fixture.world.stockpiles[fixture.center]?.quantity(of: .food) == 8)
    #expect(fixture.world.stockpiles[fixture.center]?.quantity(of: .planks) == 9)
}

@Test("scenario: unmet consumption reports the need as unmet")
func scenarioUnmetConsumptionReportsTheNeedAsUnmet() throws {
    var fixture = try houseNextToTownCenter(food: 0, planks: 10, residents: 2)
    advanceToNextConsumption(&fixture.world)
    #expect(fixture.world.populations[fixture.house]?.foodSatisfied == false)
}

@Test("scenario: empty house consumes nothing")
func scenarioEmptyHouseConsumesNothing() throws {
    var fixture = try houseNextToTownCenter(food: 10, planks: 10, residents: 0, tier: .peasants)
    advanceToNextConsumption(&fixture.world)
    #expect(fixture.world.stockpiles[fixture.center]?.quantity(of: .food) == 10)
    #expect(fixture.world.stockpiles[fixture.center]?.quantity(of: .planks) == 10)
}

@Test("house population saved before consumption still decodes")
func housePopulationFromOlderSaveDecodes() throws {
    let older = Data(#"{"population":3,"foodSatisfied":true,"planksSatisfied":true,"ticksAtCurrentSatisfaction":12}"#.utf8)
    let pop = try JSONDecoder().decode(HousePopulation.self, from: older)
    #expect(pop.population == 3)
    #expect(pop.foodShortfall == false)
    #expect(pop.planksShortfall == false)
}

@Test("scenario: peasants consume no planks")
func scenarioPeasantsConsumeNoPlanks() throws {
    var fixture = try houseNextToTownCenter(food: 10, planks: 10, residents: 4, tier: .peasants)
    advanceToNextConsumption(&fixture.world)
    #expect(fixture.world.stockpiles[fixture.center]?.quantity(of: .food) == 8)
    #expect(fixture.world.stockpiles[fixture.center]?.quantity(of: .planks) == 10)
}

@Test("scenario: merchants eat bread")
func scenarioMerchantsEatBread() throws {
    var fixture = try houseNextToTownCenter(food: 10, planks: 10, bread: 10, residents: 8, tier: .merchants)
    advanceToNextConsumption(&fixture.world)
    #expect(fixture.world.stockpiles[fixture.center]?.quantity(of: .food) == 6)
    #expect(fixture.world.stockpiles[fixture.center]?.quantity(of: .planks) == 9)
    #expect(fixture.world.stockpiles[fixture.center]?.quantity(of: .bread) == 8)
}

// MARK: - Tiers

private func run(_ world: inout World, ticks: Int) {
    for _ in 0 ..< ticks {
        world.tick()
    }
}

@Test("scenario: new house starts as peasants")
func scenarioNewHouseStartsAsPeasants() throws {
    let fixture = try houseNextToTownCenter(food: 0, planks: 0, residents: 0, tier: .peasants)
    var world = fixture.world
    world.populations = [:]
    world.tick()
    let pop = try #require(world.populations[fixture.house])
    #expect(pop.tier == .peasants)
    #expect(pop.tier.capacity == 4)
}

@Test("scenario: peasants grow with food alone")
func scenarioPeasantsGrowWithFoodAlone() throws {
    var fixture = try houseNextToTownCenter(food: 20, planks: 0, residents: 0, tier: .peasants)
    run(&fixture.world, ticks: 70)
    #expect((fixture.world.populations[fixture.house]?.population ?? 0) > 0)
}

@Test("scenario: full peasant house becomes citizens")
func scenarioFullPeasantHouseBecomesCitizens() throws {
    var fixture = try houseNextToTownCenter(food: 20, planks: 10, residents: 4, tier: .peasants)
    run(&fixture.world, ticks: 121)
    let pop = try #require(fixture.world.populations[fixture.house])
    #expect(pop.tier == .citizens)
    #expect(pop.tier.capacity == 6)
}

@Test("scenario: citizens with bread become merchants")
func scenarioCitizensWithBreadBecomeMerchants() throws {
    var fixture = try houseNextToTownCenter(food: 20, planks: 6, bread: 6, tools: 5, residents: 6, tier: .citizens)
    run(&fixture.world, ticks: 121)
    let pop = try #require(fixture.world.populations[fixture.house])
    #expect(pop.tier == .merchants)
    #expect(pop.tier.capacity == 8)
}

@Test("scenario: merchants without bread decline to citizens")
func scenarioMerchantsWithoutBreadDeclineToCitizens() throws {
    var fixture = try houseNextToTownCenter(food: 20, planks: 10, tools: 5, residents: 8, tier: .merchants)
    run(&fixture.world, ticks: 121)
    let pop = try #require(fixture.world.populations[fixture.house])
    #expect(pop.tier == .citizens)
    #expect(pop.population <= 6)
}

@Test("scenario: merchant residents pay four times the peasant rate")
func scenarioMerchantResidentsPayFourTimesThePeasantRate() throws {
    var fixture = try houseNextToTownCenter(food: 20, planks: 6, bread: 6, tools: 5, residents: 8, tier: .merchants)
    while !(fixture.world.tickCount + 1).isMultiple(of: Economy.taxIntervalTicks) {
        fixture.world.tick()
    }
    let before = fixture.world.economy.balance
    fixture.world.tick()
    #expect(fixture.world.economy.balance - before == 32)
}

@Test("house population without a tier decodes as peasants")
func housePopulationWithoutTierDecodesAsPeasants() throws {
    let older = Data(#"{"population":2,"foodSatisfied":true,"planksSatisfied":false,"ticksAtCurrentSatisfaction":3}"#.utf8)
    let pop = try JSONDecoder().decode(HousePopulation.self, from: older)
    #expect(pop.tier == .peasants)
    #expect(pop.foodSatisfied)
    #expect(!pop.planksSatisfied)
}

// MARK: - Bakery

@Test("scenario: bakery spec exposes its footprint and costs")
func scenarioBakerySpecExposesItsFootprintAndCosts() {
    let spec = BuildingCatalog.spec(for: .bakery)
    #expect(spec.footprint == Footprint(width: 2, height: 2))
    #expect(spec.cost == 90)
    #expect(spec.materialCost == [.wood: 2, .planks: 2])
    #expect(spec.shorePlacement == nil)
}

@Test("scenario: merchants consume tools")
func scenarioMerchantsConsumeTools() throws {
    var fixture = try houseNextToTownCenter(food: 10, planks: 5, bread: 5, tools: 5, residents: 8, tier: .merchants)
    advanceToNextConsumption(&fixture.world)
    #expect(fixture.world.stockpiles[fixture.center]?.quantity(of: .tools) == 4)
}

@Test("scenario: citizens cannot become merchants without tools")
func scenarioCitizensCannotBecomeMerchantsWithoutTools() throws {
    var fixture = try houseNextToTownCenter(food: 20, planks: 10, bread: 8, residents: 6, tier: .citizens)
    run(&fixture.world, ticks: 121)
    #expect(fixture.world.populations[fixture.house]?.tier == .citizens)
}
