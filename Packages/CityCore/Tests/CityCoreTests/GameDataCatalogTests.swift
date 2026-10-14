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
