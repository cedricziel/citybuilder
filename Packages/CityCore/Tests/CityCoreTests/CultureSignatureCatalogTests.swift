import Foundation
import Testing
@testable import CityCore

// Scenarios from openspec/changes/add-culture-signatures: catalog,
// culture rule, served luxury and base prices (milestone M1).

private typealias Fixture = SignatureFixture

@Test("scenario: caravanserai spec")
func scenarioCaravanseraiSpec() {
    let spec = BuildingCatalog.spec(for: .caravanserai)
    #expect(spec.footprint == Footprint(width: 3, height: 3))
    #expect(spec.cost == 200)
    #expect(spec.materialCost == [.wood: 4, .planks: 4])
    #expect(spec.upkeep == 2)
    #expect(BuildingKind.caravanserai.culture == .middleEastern)
}

@Test("culture signature catalog entries match the design table")
func cultureSignatureCatalogEntries() {
    let cultures: [BuildingKind: Culture] = [
        .meadHall: .northernEuropean, .forum: .mediterranean, .templeGarden: .eastAsian, .caravanserai: .middleEastern
    ]
    let expected: [BuildingKind: BuildingSpec] = [
        .meadHall: BuildingSpec(
            kind: .meadHall, footprint: Footprint(width: 3, height: 3),
            cost: 180, upkeep: 1, buildDurationTicks: 35, materialCost: [.wood: 6, .planks: 2]
        ),
        .forum: BuildingSpec(
            kind: .forum, footprint: Footprint(width: 3, height: 3),
            cost: 220, upkeep: 2, buildDurationTicks: 40, materialCost: [.wood: 2, .planks: 6]
        ),
        .templeGarden: BuildingSpec(
            kind: .templeGarden, footprint: Footprint(width: 3, height: 3),
            cost: 160, upkeep: 1, buildDurationTicks: 35, materialCost: [.wood: 2, .planks: 4]
        ),
        .caravanserai: BuildingSpec(
            kind: .caravanserai, footprint: Footprint(width: 3, height: 3),
            cost: 200, upkeep: 2, buildDurationTicks: 40, materialCost: [.wood: 4, .planks: 4]
        )
    ]
    for (kind, culture) in cultures {
        #expect(BuildingCatalog.spec(for: kind) == expected[kind])
        #expect(kind.culture == culture)
        #expect(World.stockpileCapacity(for: kind) == 16)
        #expect(Tech.unlocking(kind) == nil)
        #expect(kind.fuel == FuelSpec(good: culture.luxury, amount: 1, intervalTicks: 100))
        #expect(!kind.isUnique)
    }
    #expect(BuildingKind.cultureSignatures == [.meadHall, .forum, .templeGarden, .caravanserai])
}

@Test("scenario: forum in an antiquity start")
func scenarioForumInAnAntiquityStart() throws {
    var world = World.newGame(layout: .singleIsland, seed: 0, culture: .mediterranean, age: .antiquity)
    world.seedUnlimitedTestInventory()
    let anchor = try #require(Fixture.freeAnchor(for: .forum, in: world))
    #expect(world.canPlace(.forum, at: anchor) == .allowed)
}

@Test("scenario: no caravanserai in the north")
func scenarioNoCaravanseraiInTheNorth() {
    let world = World.fixtureWithTerrain(width: 8, height: 8, fill: .grass, seed: 1)
    #expect(world.canPlace(.caravanserai, at: TileCoordinate(x: 1, y: 1)) == .rejected(.wrongCulture(.middleEastern)))
}

@Test("scenario: forum served wine")
func scenarioForumServedWine() {
    var world = Fixture.grass()
    world.culture = .mediterranean
    let forum = Fixture.inject(.forum, at: TileCoordinate(x: 2, y: 2), in: &world)
    world.stockpiles[forum]?.deposit(.wine, amount: 2)
    Fixture.runUntilBefore(multipleOf: 100, in: &world)
    world.tick()
    #expect(world.stockpiles[forum]?.quantity(of: .wine) == 1)
    #expect(world.buildings[forum]?.fuelled == true)
    #expect(world.buildings[forum]?.isServed == true)
}

@Test("scenario: wine price")
func scenarioWinePrice() {
    #expect(Good.wine.basePrice == 16)
}

@Test("scenario: every good is priced")
func scenarioEveryGoodIsPriced() {
    #expect(Good.allCases.allSatisfy { $0.basePrice >= 1 })
    let expected: [Good: Int64] = [
        .wood: 4, .planks: 8, .food: 4, .bread: 12, .grain: 3, .flour: 6, .ore: 5, .charcoal: 5, .iron: 14, .tools: 30,
        .hops: 3, .grapes: 3, .teaLeaves: 3, .coffeeCherries: 3, .beer: 16, .wine: 16, .tea: 16, .coffee: 16
    ]
    #expect(Dictionary(uniqueKeysWithValues: Good.allCases.map { ($0, $0.basePrice) }) == expected)
}

@Test("a new caravanserai exports nothing")
func newCaravanseraiExportsNothing() {
    #expect(Building(id: EntityID(raw: 3), kind: .caravanserai, anchor: TileCoordinate(x: 1, y: 1)).exportGood == nil)
}
