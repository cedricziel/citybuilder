import Foundation
import Testing
@testable import CityCore

// Scenarios from openspec/changes/fix-playable-foundation/specs/population-and-needs
// (Requirement: Houses consume food and planks).

private struct Fixture {
    var world: World
    let house: EntityID
    let center: EntityID
}

private func houseNextToTownCenter(food: Int, planks: Int, residents: UInt32) throws -> Fixture {
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
    world.stockpiles[center] = stock
    var pop = HousePopulation()
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
    var fixture = try houseNextToTownCenter(food: 10, planks: 10, residents: 0)
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
