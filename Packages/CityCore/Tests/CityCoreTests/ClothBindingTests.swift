import Foundation
import Testing
@testable import CityCore

// Cloth binds merchants only where it can be made
// (openspec/changes/add-wool-cloth-chain, population-and-needs).

private func world(researched: [Tech]) -> World {
    var world = World.fixtureWithTerrain(width: 8, height: 8, fill: .grass, seed: 1)
    world.research = ResearchState(researched: researched)
    return world
}

private let withoutWeaving = Tech.allCases.filter { $0 != .weaving }

@Test("scenario: cloth is exempt from staying a merchant before weaving")
func scenarioClothIsExemptFromStayingAMerchantBeforeWeaving() {
    let early = world(researched: withoutWeaving)
    #expect(!early.bindingNeeds(of: .merchants, for: .player, advancing: false).contains(.cloth))
    #expect(early.bindingNeeds(of: .merchants, for: .player, advancing: true).contains(.cloth))
    let weaving = world(researched: Tech.allCases)
    #expect(weaving.bindingNeeds(of: .merchants, for: .player, advancing: false).contains(.cloth))
    #expect(weaving.bindingNeeds(of: .merchants, for: .player, advancing: true).contains(.cloth))
}

@Test("scenario: rival houses are never held to cloth")
func scenarioRivalHousesAreNeverHeldToCloth() {
    let world = world(researched: Tech.allCases)
    for advancing in [false, true] {
        let needs = world.bindingNeeds(of: .merchants, for: .rival(1), advancing: advancing)
        #expect(!needs.contains(.cloth))
        #expect(needs.contains(.bread) && needs.contains(.tools))
    }
}

@Test("the other tiers' needs do not change")
func otherTiersKeepTheirNeeds() {
    let world = world(researched: withoutWeaving)
    for tier in [HouseTier.peasants, .citizens] {
        #expect(world.bindingNeeds(of: tier, for: .player, advancing: true) == tier.needs(in: world.culture))
    }
    #expect(world.bindingNeeds(of: .merchants, for: .player, advancing: false).contains(.tools))
}

@Test("scenario: a rival's merchant house keeps its tier without cloth")
func scenarioARivalsMerchantHouseKeepsItsTierWithoutCloth() {
    var world = SignatureFixture.grass()
    let store = SignatureFixture.inject(.warehouse, at: TileCoordinate(x: 0, y: 1), in: &world, owner: .rival(1))
    for good in HouseTier.merchants.needs(in: world.culture) where good != .cloth {
        world.stockpiles[store]?.deposit(good, amount: 30)
    }
    for x in 0 ... 12 {
        world.enqueue(.place(.road, at: TileCoordinate(x: x, y: 4)))
    }
    let house = SignatureFixture.inject(.house, at: TileCoordinate(x: 6, y: 2), in: &world, owner: .rival(1))
    var population = HousePopulation()
    population.tier = .merchants
    population.population = 8
    world.populations[house] = population
    _ = SignatureFixture.run(&world, ticks: 300)
    #expect(world.populations[house]?.tier == .merchants)
}
