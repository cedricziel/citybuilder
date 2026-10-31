import Testing
@testable import CityCore

// Scenarios from openspec/changes/tier-needs-data (population-and-needs).

@Test("scenario: shipped tiers keep their values")
func scenarioShippedTiersKeepTheirValues() {
    #expect(HouseTier.allCases == [.peasants, .citizens, .merchants])
    #expect(HouseTier.allCases.map(\.rawValue) == [1, 2, 3])
    #expect(HouseTier.allCases.map(\.capacity) == [4, 6, 8])
    #expect(HouseTier.allCases.map(\.needs) == [[.food], [.food, .planks], [.food, .planks, .bread, .tools, .cloth]])
    #expect(HouseTier.allCases.map(\.taxPerResident) == [1, 2, 4])
    #expect(HouseTier.allCases.map(\.nameKey) == ["tier.peasants.name", "tier.citizens.name", "tier.merchants.name"])
    #expect(HouseTier.merchants.nameKey(in: .mediterranean) == "culture.mediterranean.tierName.merchants")
    #expect(HouseTier.merchants.nameKey(in: .northernEuropean) == "tier.merchants.name")
}

@Test("scenario: a need without its own rate is eaten one per eight residents")
func scenarioANeedWithoutItsOwnRateIsEatenOnePerEightResidents() {
    // No shipped tier needs iron; a pack's `neededBy` could add it.
    #expect(HousePopulation.amount(of: .iron, residents: 9) == 2)
    #expect(HousePopulation.amount(of: .tools, residents: 9) == 2)
    #expect(HousePopulation.amount(of: .food, residents: 9) == 5)
}

@Test("scenario: a good the tier does not need is not eaten")
func scenarioAGoodTheTierDoesNotNeedIsNotEaten() {
    var house = HousePopulation()
    house.tier = .citizens
    house.population = 6
    #expect(house.consumption(of: .tools, in: .northernEuropean) == 0)
    #expect(house.consumption(of: .planks, in: .northernEuropean) == 1)
}
