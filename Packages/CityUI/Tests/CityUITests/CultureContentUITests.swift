import CityCore
import Foundation
import Testing
@testable import CityUI

// Scenarios from openspec/changes/add-culture-content.

@MainActor
@Test("scenario: mediterranean palette")
func scenarioMediterraneanPalette() {
    let session = GameSession(world: World.newGame(layout: .singleIsland, seed: 0, culture: .mediterranean))
    let kinds = BuildPalette.visibleKinds(isHidden: session.isHidden)
    #expect(kinds.contains(.vineyard))
    #expect(kinds.contains(.winery))
    #expect(!kinds.contains(.brewery))
    #expect(!kinds.contains(.teaHouse))
    #expect(!kinds.contains(.roastery))
}

@Test("cultivation lists only the world culture's buildings")
func cultivationListsOnlyTheWorldCulturesBuildings() throws {
    let world = World.newGame(layout: .singleIsland, seed: 0, culture: .eastAsian)
    let row = try #require(ResearchPanelModel(world: world).rows.first { $0.tech == .cultivation })
    #expect(row.unlocks == "Tea Garden, Tea House")
}

@Test("inspector lists the culture luxury among merchants' needs")
func inspectorListsTheCultureLuxuryAmongMerchantsNeeds() throws {
    var world = World.fixtureWithTerrain(width: 8, height: 8, fill: .grass, seed: 1)
    let anchor = TileCoordinate(x: 2, y: 2)
    world.enqueue(.place(.house, at: anchor))
    for _ in 0 ..< 30 {
        world.tick()
    }
    let house = try #require(world.occupiedTiles[anchor])
    var pop = HousePopulation()
    pop.tier = .merchants
    pop.population = 8
    pop.setSatisfied(.food, true)
    pop.setSatisfied(.tea, true)
    let snapshot = withHousePopulations(world.snapshot(), [house: pop], culture: .eastAsian)
    let lines = InspectorViewModel.make(from: snapshot, tile: anchor, buildings: snapshot.buildings).bullets
    #expect(lines.contains("Needs: food ✓ · planks ✓ · bread ✗ · tools ✗ · tea ✓"))
}
