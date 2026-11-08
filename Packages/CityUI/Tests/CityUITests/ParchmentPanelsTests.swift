import Testing
@testable import CityCore
@testable import CityUI

// Scenarios from openspec/changes/parchment-panels/specs/platform-shells/spec.md.

private func inspector(for kind: BuildingKind, population: HousePopulation? = nil) throws -> InspectorViewModel {
    var world = World.fixtureWithTerrain(width: 8, height: 8, fill: .grass, seed: 1)
    let anchor = TileCoordinate(x: 2, y: 2)
    world.enqueue(.place(kind, at: anchor))
    for _ in 0 ..< 30 {
        world.tick()
    }
    var snapshot = world.snapshot()
    if let population {
        let id = try #require(world.occupiedTiles[anchor])
        snapshot = withHousePopulations(snapshot, [id: population])
    }
    return InspectorViewModel.make(from: snapshot, tile: anchor, buildings: snapshot.buildings)
}

@Test("scenario: shared parchment colours")
func scenarioSharedParchmentColours() {
    #expect(Parchment.paperHex == 0xEDDDB3)
    #expect(Parchment.edgeHex == 0x6B4A29)
    #expect(Parchment.inkHex == 0x3D2914)
}

@Test("scenario: need chips for a house")
func scenarioNeedChipsForAHouse() throws {
    var population = HousePopulation()
    population.tier = .citizens
    population.population = 4
    population.setSatisfied(.food, true)
    population.setSatisfied(.planks, false)
    let inspector = try inspector(for: .house, population: population)
    #expect(inspector.needChips.map(\.good) == [.food, .planks])
    #expect(inspector.needChips.map(\.isMet) == [true, false])
    #expect(inspector.needChips.map(\.spokenLabel) == ["food, met", "planks, short"])
}

@Test("need chips take the place of the Needs line")
func needChipsReplaceTheNeedsKeyLine() throws {
    var population = HousePopulation()
    population.population = 2
    let inspector = try inspector(for: .house, population: population)
    #expect(!inspector.needChips.isEmpty)
    #expect(!inspector.calloutKeyLines.contains { $0.hasPrefix("Needs:") })
    #expect(inspector.calloutKeyLines.first == "Residents: 2/4")
}

@Test("scenario: recipe for a bakery")
func scenarioRecipeForABakery() throws {
    let recipe = try #require(try inspector(for: .bakery).recipe)
    let catalog = try #require(ProductionCatalog.recipe(for: .bakery))
    #expect(try recipe.inputs == [GoodAmount(good: .flour, amount: #require(catalog.inputs[.flour]))])
    #expect(try recipe.outputs == [GoodAmount(good: .bread, amount: #require(catalog.outputs[.bread]))])
}

@Test("scenario: no recipe for a house")
func scenarioNoRecipeForAHouse() throws {
    #expect(try inspector(for: .house).recipe == nil)
}
