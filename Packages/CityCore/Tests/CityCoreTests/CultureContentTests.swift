import Foundation
import Testing
@testable import CityCore

// Scenarios from openspec/changes/add-culture-content.

@Test("scenario: winery makes wine")
func scenarioWineryMakesWine() throws {
    var world = World.fixtureWithTerrain(width: 8, height: 8, fill: .grass, seed: 1)
    world.culture = .mediterranean
    world.enqueue(.place(.winery, at: TileCoordinate(x: 1, y: 1)))
    for _ in 0 ..< 60 {
        world.tick()
    }
    let winery = try #require(world.occupiedTiles[TileCoordinate(x: 1, y: 1)])
    #expect(world.buildings[winery]?.state == .operational)
    world.stockpiles[winery]?.deposit(.grapes, amount: 2)
    world.productions[winery] = ProductionProgress()
    var elapsed = 0
    while elapsed < 200 {
        elapsed += 1
        if world.tick().events.contains(.productionCycleCompleted(producer: winery, kind: .winery)) { break }
    }
    #expect(elapsed == 50)
    #expect(world.stockpiles[winery]?.quantity(of: .wine) == 1)
}

@Test("scenario: luxury per culture")
func scenarioLuxuryPerCulture() {
    #expect(Culture.allCases.map(\.luxury) == [.beer, .wine, .tea, .coffee])
}

@Test("scenario: no vineyards in the north")
func scenarioNoVineyardsInTheNorth() {
    let world = World.fixtureWithTerrain(width: 8, height: 8, fill: .grass, seed: 1)
    #expect(world.canPlace(.vineyard, at: TileCoordinate(x: 1, y: 1)) == .rejected(.wrongCulture(.mediterranean)))
}

@Test("scenario: brewery needs cultivation")
func scenarioBreweryNeedsCultivation() {
    #expect(World.newGame().canPlace(.brewery, at: TileCoordinate(x: 0, y: 0)) == .rejected(.locked(.cultivation)))
}

@Test("scenario: east asian merchants need tea")
func scenarioEastAsianMerchantsNeedTea() {
    #expect(HouseTier.merchants.needs(in: .eastAsian) == [.food, .planks, .bread, .tools, .tea])
    #expect(HouseTier.citizens.needs(in: .eastAsian) == [.food, .planks])
}

@Test("scenario: old saves keep their satisfaction")
func scenarioOldSavesKeepTheirSatisfaction() throws {
    let json = """
    {"population": 5, "tier": 3, "foodSatisfied": true, "planksSatisfied": false,
     "breadSatisfied": true, "toolsSatisfied": false, "foodShortfall": false,
     "planksShortfall": true, "breadShortfall": false, "toolsShortfall": true}
    """
    let pop = try JSONDecoder().decode(HousePopulation.self, from: Data(json.utf8))
    #expect(pop.isSatisfied(.food))
    #expect(!pop.isSatisfied(.planks))
    #expect(pop.isSatisfied(.bread))
    #expect(!pop.isSatisfied(.tools))
}

@Test("scenario: culture goods are catalogued")
func scenarioCultureGoodsAreCatalogued() {
    let goods: [Good] = [.hops, .beer, .grapes, .wine, .teaLeaves, .tea, .coffeeCherries, .coffee]
    #expect(goods.allSatisfy { !GoodsCatalog.spec(for: $0).displayName.isEmpty })
}

@Test("scenario: tea house spec")
func scenarioTeaHouseSpec() {
    let spec = BuildingCatalog.spec(for: .teaHouse)
    #expect(spec.footprint == Footprint(width: 2, height: 2))
    #expect(spec.cost == 120)
    #expect(spec.materialCost == [.wood: 3, .planks: 3])
    #expect(BuildingKind.teaHouse.culture == .eastAsian)
}

@Test("merchants eat 1 luxury per 8 residents")
func merchantsEatOneLuxuryPerEightResidents() {
    var pop = HousePopulation()
    pop.tier = .merchants
    pop.population = 8
    #expect(pop.consumption(of: .tea, in: .eastAsian) == 1)
    #expect(pop.consumption(of: .beer, in: .eastAsian) == 0)
}
