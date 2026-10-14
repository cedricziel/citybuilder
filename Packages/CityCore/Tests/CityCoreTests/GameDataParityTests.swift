import Foundation
import Testing
@testable import CityCore

// Migration gate for game-data-codegen (design D8), deleted in task 3.3:
// every value generated from the packs into `GameDataParity` equals the
// value the hand-written catalogs hold today.

private typealias Parity = GameDataParity

private func parity<T: RawRepresentable>(_ value: some RawRepresentable<String>) throws -> T where T.RawValue == String {
    try #require(T(rawValue: value.rawValue), "\(T.self) has no case \(value.rawValue)")
}

private func raw(_ amounts: [some RawRepresentable<String> & Hashable: Int]) -> [String: Int] {
    Dictionary(uniqueKeysWithValues: amounts.map { ($0.key.rawValue, $0.value) })
}

@Test func parityGoodsKeepTheirOrderAndValues() throws {
    #expect(Parity.Good.allCases.map(\.rawValue) == Good.allCases.map(\.rawValue))
    #expect(Parity.GoodsCatalog.all.map(\.good) == Parity.Good.allCases)
    for good in Good.allCases {
        let generated: Parity.Good = try parity(good)
        let spec = GoodsCatalog.spec(for: good), generatedSpec = Parity.GoodsCatalog.spec(for: generated)
        #expect(generatedSpec.good == generated)
        #expect(generatedSpec.displayName == spec.displayName, "\(good)")
        #expect(generatedSpec.stackUnit == spec.stackUnit, "\(good)")
        #expect(generated.basePrice == good.basePrice, "\(good)")
    }
}

@Test func parityBuildingKindsAreTheSameSet() {
    #expect(Set(Parity.BuildingKind.allCases.map(\.rawValue)) == Set(BuildingKind.allCases.map(\.rawValue)))
    #expect(Parity.BuildingCatalog.all.map(\.kind) == Parity.BuildingKind.allCases)
}

@Test(arguments: BuildingKind.allCases)
func parityBuildingSpec(kind: BuildingKind) throws {
    let generated: Parity.BuildingKind = try parity(kind)
    let spec = BuildingCatalog.spec(for: kind), generatedSpec = Parity.BuildingCatalog.spec(for: generated)
    #expect(generatedSpec.kind == generated)
    #expect(generatedSpec.footprint == spec.footprint)
    #expect(generatedSpec.cost == spec.cost)
    #expect(generatedSpec.upkeep == spec.upkeep)
    #expect(generatedSpec.buildDurationTicks == spec.buildDurationTicks)
    #expect(generatedSpec.shorePlacement == spec.shorePlacement)
    #expect(raw(generatedSpec.materialCost) == raw(spec.materialCost))
    #expect(generatedSpec.requiredTerrain == spec.requiredTerrain)
}

@Test(arguments: BuildingKind.allCases)
func parityBuildingValues(kind: BuildingKind) throws {
    let generated: Parity.BuildingKind = try parity(kind)
    #expect(generated.storage == World.stockpileCapacity(for: kind))
    #expect(generated.culture?.rawValue == kind.culture?.rawValue)
    #expect(generated.obsoletedBy?.rawValue == kind.obsoletedBy?.rawValue)
    let signatureOf = Parity.Culture.allCases.first { $0.signature == generated }
    #expect(signatureOf?.rawValue == kind.signatureCulture?.rawValue)
}

/// The labels and drawers are compared with CityUI's tables in
/// CityUITests; here every kind needs a label, and only the road and the
/// town center stay out of the drawers.
@Test(arguments: GameDataParity.BuildingKind.allCases)
func parityBuildingLabelAndCategoryArePresent(kind: GameDataParity.BuildingKind) {
    #expect(!kind.displayName.isEmpty)
    #expect((kind.category == nil) == [.road, .townCenter].contains(kind))
    #expect([nil, "town", "gather", "craft"].contains(kind.category))
}

@Test(arguments: BuildingKind.allCases)
func parityRecipe(kind: BuildingKind) throws {
    let recipe = ProductionCatalog.recipe(for: kind)
    let generated = try Parity.ProductionCatalog.recipe(for: parity(kind))
    #expect(generated.map { raw($0.inputs) } == recipe.map { raw($0.inputs) })
    #expect(generated.map { raw($0.outputs) } == recipe.map { raw($0.outputs) })
    #expect(generated?.cycleTicks == recipe?.cycleTicks)
}

@Test func parityLegacyBuildingIdsDecode() throws {
    let decoder = JSONDecoder()
    #expect(try decoder.decode(Parity.BuildingKind.self, from: Data(#""lumberjack_hut""#.utf8)) == .lumberjackHut)
    #expect(try decoder.decode(Parity.BuildingKind.self, from: Data(#""town_center""#.utf8)) == .townCenter)
    #expect(try decoder.decode(Parity.BuildingKind.self, from: Data(#""sawmill""#.utf8)) == .sawmill)
    #expect(throws: DecodingError.self) { try decoder.decode(Parity.BuildingKind.self, from: Data(#""castle""#.utf8)) }
    #expect(try JSONEncoder().encode(Parity.BuildingKind.lumberjackHut) == Data(#""lumberjack-hut""#.utf8))
}

@Test func parityCultures() throws {
    #expect(Parity.Culture.allCases.map(\.rawValue) == Culture.allCases.map(\.rawValue))
    for culture in Culture.allCases {
        let generated: Parity.Culture = try parity(culture)
        #expect(generated.displayName == culture.displayName)
        #expect(generated.blurb == culture.blurb)
        #expect(generated.signature.rawValue == culture.signature.rawValue)
        #expect(generated.residentNames == ResidentNames.list(for: culture))
        let chain = culture.luxuryChain, generatedChain = generated.luxuryChain
        #expect(generatedChain.raw.rawValue == chain.raw.rawValue)
        #expect(generatedChain.good.rawValue == chain.good.rawValue)
        #expect(generatedChain.garden.rawValue == chain.garden.rawValue)
        #expect(generatedChain.producer.rawValue == chain.producer.rawValue)
        for tier in HouseTier.allCases {
            #expect(generated.tierName(tier) == tier.displayName(in: culture), "\(culture) \(tier)")
        }
    }
}

@Test func parityTechs() throws {
    #expect(Parity.Tech.allCases.map(\.rawValue) == Tech.allCases.map(\.rawValue))
    for tech in Tech.allCases {
        let generated: Parity.Tech = try parity(tech)
        #expect(generated.displayName == tech.displayName)
        #expect(generated.cost == tech.cost)
        #expect(generated.prerequisites.map(\.rawValue) == tech.prerequisites.map(\.rawValue))
        #expect(generated.unlocks.map(\.rawValue) == tech.unlocks.map(\.rawValue), "\(tech)")
        #expect(generated.age.rawValue == tech.age.rawValue)
        #expect(generated.era?.rawValue == tech.era?.rawValue)
        #expect(generated.eraGate?.tier == tech.eraGate?.tier)
        #expect(generated.eraGate?.residents == tech.eraGate?.residents)
    }
}

@Test func parityAges() throws {
    #expect(Parity.Age.allCases.map(\.rawValue) == Age.allCases.map(\.rawValue))
    #expect(Parity.Age.allCases.map(\.signature.rawValue) == BuildingKind.signatures.map(\.rawValue))
    for age in Age.allCases {
        let generated: Parity.Age = try parity(age)
        #expect(generated.displayName == age.displayName)
        #expect(generated.startYear == age.startYear)
        #expect(generated.blurb == age.blurb)
        #expect(generated.rivalResidents == age.rivalResidentThreshold)
    }
}
