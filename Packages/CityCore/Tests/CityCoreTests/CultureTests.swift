import Testing
@testable import CityCore

// Scenarios from openspec/changes/add-cultures.

@Test("scenario: new game uses the chosen culture")
func scenarioNewGameUsesTheChosenCulture() {
    #expect(World.newGame(layout: .singleIsland, seed: 0, culture: .eastAsian).culture == .eastAsian)
}

@Test("scenario: default culture is northern european")
func scenarioDefaultCultureIsNorthernEuropean() {
    #expect(World.newGame().culture == .northernEuropean)
    #expect(World.newGame(layout: .singleIsland, seed: 0).culture == .northernEuropean)
}

@Test("scenario: snapshot carries the culture")
func scenarioSnapshotCarriesTheCulture() {
    #expect(World.newGame(layout: .singleIsland, seed: 0, culture: .mediterranean).snapshot().culture == .mediterranean)
}

@Test("culture raw values are kebab case")
func cultureRawValuesAreKebabCase() {
    #expect(Culture.allCases.map(\.rawValue) == ["northern-european", "mediterranean", "east-asian", "middle-eastern"])
}
