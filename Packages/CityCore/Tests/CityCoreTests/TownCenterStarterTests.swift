import Foundation
import Testing
@testable import CityCore

// Tests for the town center starter inventory added by
// `add-build-materials-cost` → M5. Scenarios under
// `Requirement: Town center starter inventory` in
// openspec/changes/add-build-materials-cost/specs/buildings-and-construction/spec.md.

private func townCenter(in world: World) -> (id: EntityID, building: Building)? {
    for (id, building) in world.buildings where building.kind == .townCenter {
        return (id, building)
    }
    return nil
}

@Test("scenario: fresh-world town center holds starter goods")
func scenarioFreshWorldTownCenterHoldsStarterGoods() throws {
    let world = World.newGame()
    let center = try #require(townCenter(in: world))
    let stockpile = try #require(world.stockpiles[center.id])
    #expect(stockpile.quantity(of: .wood) == 6)
    #expect(stockpile.quantity(of: .planks) == 5)
    #expect(stockpile.quantity(of: .food) == 2)
}

@Test("scenario: starter goods are part of the island stockpile aggregate")
func scenarioStarterGoodsArePartOfTheIslandStockpileAggregate() throws {
    let world = World.newGame()
    let snapshot = world.snapshot()
    let onlyIsland = try #require(world.islands.first?.id)
    let summary = try #require(snapshot.islandSummaries[onlyIsland])
    #expect(summary.stockpile[.wood] == 6)
    #expect(summary.stockpile[.planks] == 5)
    #expect(summary.stockpile[.food] == 2)
}

@Test("scenario: archipelago seeds a town center on every island")
func scenarioArchipelagoSeedsATownCenterOnEveryIsland() {
    let world = World.newGame(layout: .archipelago, seed: 5)
    let townCenters = world.buildings.values.filter { $0.kind == .townCenter }
    // Every island that's large enough to host the 3×3 footprint gets
    // a town center. The archipelago generator produces ≥ 2 islands;
    // each should have its own seeded center.
    #expect(townCenters.count == world.islands.count)
}

@Test("scenario: fresh-world town center is operational")
func scenarioFreshWorldTownCenterIsOperational() throws {
    let world = World.newGame()
    let center = try #require(townCenter(in: world))
    #expect(center.building.state == .operational)
}
