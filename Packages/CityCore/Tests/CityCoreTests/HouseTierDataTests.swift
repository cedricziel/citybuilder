import Testing
@testable import CityCore

// Scenarios from openspec/changes/tier-needs-data (population-and-needs).

@Test("scenario: shipped tiers keep their values")
func scenarioShippedTiersKeepTheirValues() {
    #expect(HouseTier.allCases == [.peasants, .citizens, .merchants])
    #expect(HouseTier.allCases.map(\.rawValue) == [1, 2, 3])
    #expect(HouseTier.allCases.map(\.capacity) == [4, 6, 8])
    #expect(HouseTier.allCases.map(\.needs) == [[.food], [.food, .planks], [.food, .planks, .bread, .tools]])
    #expect(HouseTier.allCases.map(\.taxPerResident) == [1, 2, 4])
    #expect(HouseTier.allCases.map(\.displayName) == ["Peasants", "Citizens", "Merchants"])
    let names: [Culture: [String]] = [
        .northernEuropean: ["Peasants", "Citizens", "Merchants"],
        .mediterranean: ["Plebeians", "Citizens", "Patricians"],
        .eastAsian: ["Farmers", "Artisans", "Scholars"],
        .middleEastern: ["Farmers", "Craftsmen", "Merchants"]
    ]
    #expect(Set(names.keys) == Set(Culture.allCases))
    for (culture, expected) in names {
        #expect(HouseTier.allCases.map { $0.displayName(in: culture) } == expected, "\(culture)")
    }
}
