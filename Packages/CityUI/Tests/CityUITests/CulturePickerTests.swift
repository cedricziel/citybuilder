import Testing
@testable import CityCore
@testable import CityUI

// Scenarios from openspec/changes/add-cultures.

@MainActor
@Test("scenario: chosen culture reaches the world")
func scenarioChosenCultureReachesTheWorld() {
    let dialog = NewGameDialogViewModel()
    #expect(dialog.culture == .northernEuropean)
    dialog.culture = .middleEastern
    #expect(dialog.commit()?.culture == .middleEastern)
}

@MainActor
@Test("scenario: cancel resets the culture")
func scenarioCancelResetsTheCulture() {
    let dialog = NewGameDialogViewModel()
    dialog.culture = .eastAsian
    dialog.cancel()
    #expect(dialog.culture == .northernEuropean)
}

@Test("scenario: mediterranean inspector")
func scenarioMediterraneanInspector() throws {
    var world = World.fixtureWithTerrain(width: 8, height: 8, fill: .grass, seed: 1)
    world.culture = .mediterranean
    let anchor = TileCoordinate(x: 2, y: 2)
    world.enqueue(.place(.house, at: anchor))
    for _ in 0 ..< 30 {
        world.tick()
    }
    let house = try #require(world.occupiedTiles[anchor])
    world.populations[house] = HousePopulation()
    let snapshot = world.snapshot()
    let lines = InspectorViewModel.make(from: snapshot, tile: anchor, buildings: snapshot.buildings).bullets
    #expect(lines.contains("Tier: Plebeians"))
}

@Test("scenario: resident line")
func scenarioResidentLine() {
    var pop = HousePopulation()
    pop.population = 2
    pop.setSatisfied(.food, false)
    let lines = InspectorViewModel.residentLines(house: EntityID(raw: 7), population: pop, culture: .northernEuropean)
    #expect(lines.count == 2)
    #expect(lines.allSatisfy { $0.hasSuffix(" · Peasants · wants food") })
}
