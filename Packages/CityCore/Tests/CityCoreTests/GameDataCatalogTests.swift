import Foundation
import Testing
@testable import CityCore

// Scenarios from openspec/changes/game-data-codegen (game-data-catalog).

@Test("scenario: legacy building identifiers still decode")
func scenarioLegacyBuildingIdentifiersStillDecode() throws {
    let decoder = JSONDecoder()
    #expect(try decoder.decode(BuildingKind.self, from: Data(#""lumberjack_hut""#.utf8)) == .lumberjackHut)
    #expect(try decoder.decode(BuildingKind.self, from: Data(#""town_center""#.utf8)) == .townCenter)
    #expect(try JSONEncoder().encode(BuildingKind.lumberjackHut) == Data(#""lumberjack-hut""#.utf8))
    #expect(throws: DecodingError.self) { try decoder.decode(BuildingKind.self, from: Data(#""castle""#.utf8)) }
}

@Test("scenario: every good has a consumer")
func scenarioEveryGoodHasAConsumer() {
    let recipeInputs = BuildingKind.allCases.flatMap { ProductionCatalog.recipe(for: $0)?.inputs.keys.map(\.self) ?? [] }
    let materials = BuildingCatalog.all.flatMap(\.materialCost.keys)
    let luxuries = Culture.allCases.map(\.luxury)
    let needs = HouseTier.allCases.flatMap(\.needs)
    let consumed = Set(recipeInputs + materials + luxuries + needs)
    let unused = Good.allCases.filter { !consumed.contains($0) }
    #expect(unused.isEmpty, "goods nothing consumes: \(unused)")
}

@Test func everyContentCaseHasItsDisplayValues() {
    for kind in BuildingKind.allCases {
        #expect(!kind.displayName.isEmpty, "\(kind)")
        #expect((kind.category == nil) == [.road, .townCenter].contains(kind), "\(kind)")
    }
    for culture in Culture.allCases {
        #expect(!culture.displayName.isEmpty && !culture.blurb.isEmpty, "\(culture)")
    }
    for tech in Tech.allCases {
        #expect(!tech.displayName.isEmpty, "\(tech)")
    }
    for age in Age.allCases {
        #expect(!age.displayName.isEmpty && !age.blurb.isEmpty, "\(age)")
    }
    #expect(BuildingKind.signatures == [.monument, .guildHall, .gallery, .steamEngine, .powerPlant])
}
