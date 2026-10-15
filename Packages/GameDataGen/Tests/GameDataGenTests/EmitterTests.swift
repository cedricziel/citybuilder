import GameDataModel
import Testing

private func emitted(_ file: String, from source: InMemorySource = Fixtures.source()) throws -> String {
    let files = try SwiftEmitter.emit(Fixtures.load(source).get())
    return try #require(files[file], "no \(file) in \(files.keys.sorted())")
}

/// The case names of `enum <type>` in declaration order.
private func cases(of type: String, in source: String) -> [String] {
    guard let start = source.range(of: "public enum \(type):") else { return [] }
    return source[start.upperBound...].split(separator: "\n").dropFirst()
        .prefix { $0.hasPrefix("    case ") }
        .compactMap { $0.split(separator: " ").dropFirst().first.map(String.init) }
}

@Test("scenario: case order follows manifest and item order")
func caseOrder() throws {
    let packA = "items:\n  - { kind: Good, id: a1, name: A1, unit: u, basePrice: 1, neededBy: [merchants] }\n"
        + "  - { kind: Good, id: a2, name: A2, unit: u, basePrice: 1, neededBy: [merchants] }\n"
    let packB = "items:\n  - { kind: Good, id: b1, name: B1, unit: u, basePrice: 1, neededBy: [merchants] }\n"
        + "  - { kind: Good, id: b2, name: B2, unit: u, basePrice: 1, neededBy: [merchants] }\n"
    let source = Fixtures.source(Fixtures.packs + [("a", packA), ("b", packB)])
    let goods = try cases(of: "Good", in: emitted("Good+Generated.swift", from: source))
    #expect(goods == ["wood", "planks", "hops", "beer", "a1", "a2", "b1", "b2"])
}

@Test("scenario: adding a culture pack adds the whole culture")
func addingCulturePack() throws {
    let base = Fixtures.source([("core", Fixtures.core), ("ages", Fixtures.ages)])
    #expect(try cases(of: "Culture", in: emitted("Culture+Generated.swift", from: base)).isEmpty)
    #expect(try emitted("Tech+Generated.swift", from: base).contains("case .cultivation: []"))

    #expect(try cases(of: "Culture", in: emitted("Culture+Generated.swift")) == ["northernEuropean"])
    let goods = try cases(of: "Good", in: emitted("Good+Generated.swift"))
    #expect(goods.contains("hops") && goods.contains("beer"))
    let buildings = try cases(of: "BuildingKind", in: emitted("BuildingKind+Generated.swift"))
    #expect(["hopGarden", "brewery", "meadHall"].allSatisfy(buildings.contains))
    #expect(try emitted("Tech+Generated.swift").contains("case .cultivation: [.hopGarden, .brewery]"))
}

@Test func emitsCasesWithRawValuesForHyphenatedIds() throws {
    let source = try emitted("BuildingKind+Generated.swift")
    #expect(source.contains("    case lumberjackHut = \"lumberjack-hut\"\n"))
    #expect(source.contains("    case house\n"))
}

@Test func emitsLegacyIdsAsDecodeAliases() throws {
    #expect(try emitted("BuildingKind+Generated.swift").contains("case \"lumberjack_hut\": \"lumberjack-hut\""))
}

@Test func emitsBuildingCatalogWithMergedValues() throws {
    let source = try emitted("BuildingKind+Generated.swift")
    #expect(source.contains(
        "case .sawmill: BuildingSpec(kind: .sawmill, footprint: Footprint(width: 2, height: 2), cost: 120, upkeep: 2, "
            + "buildDurationTicks: 30, shorePlacement: nil, materialCost: [.planks: 1, .wood: 4], requiredTerrain: nil)"
    ))
    #expect(source.contains("shorePlacement: ShorePlacement(minLandTiles: 1, minWaterTiles: 1)"))
    #expect(source.contains("case .lumberjackHut: \"Lumberjack\""))
    #expect(source.contains("case .sawmill: \"Sawmill\""))
    #expect(source.contains("case .house: 8"))
    #expect(source.contains("case .sawmill: nil"))
    #expect(source.contains("case .lumberjackHut: \"gather\""))
    #expect(source.contains("case .brewery: .northernEuropean"))
}

@Test func emitsProductionRecipes() throws {
    let source = try emitted("ProductionCatalog+Generated.swift")
    #expect(source.contains("case .sawmill: ProductionRecipe(inputs: [.wood: 1], outputs: [.planks: 1], cycleTicks: 25)"))
    #expect(source.contains("case .lumberjackHut: ProductionRecipe(inputs: [:], outputs: [.wood: 1], cycleTicks: 30)"))
    #expect(source.contains("case .monument: ProductionRecipe(inputs: [.wood: 2], outputs: [:], cycleTicks: 60)"))
    #expect(source.contains("case .house: nil"))
}

@Test func emitsCultureTechAndAgeValues() throws {
    let culture = try emitted("Culture+Generated.swift")
    #expect(culture.contains("case (.northernEuropean, .merchants): \"Merchants\""))
    #expect(culture.contains("LuxuryChain(raw: .hops, good: .beer, garden: .hopGarden, producer: .brewery)"))
    #expect(culture.contains("case .northernEuropean: [\"Astrid\", \"Bjorn\"]"))
    let tech = try emitted("Tech+Generated.swift")
    #expect(tech.contains("case .feudalOrder: (.citizens, 20)"))
    #expect(tech.contains("case .feudalOrder: \"Feudal Order\""))
    #expect(tech.contains("case .seafaring: [.port]"))
    let age = try emitted("Age+Generated.swift")
    #expect(age.contains("case .antiquity: -499"))
    #expect(age.contains("case .medieval: 24"))
}

@Test func escapesStringLiterals() throws {
    let extra = "items:\n  - { kind: Good, id: salt, name: 'Sea \"Salt\" \\ grey', unit: sacks, basePrice: 3, neededBy: [merchants] }\n"
    let source = try emitted("Good+Generated.swift", from: Fixtures.withExtraPack(extra))
    #expect(source.contains(#"displayName: "Sea \"Salt\" \\ grey""#))
}

@Test func everyFileCarriesTheGeneratedBanner() throws {
    for (name, source) in try SwiftEmitter.emit(Fixtures.load().get()) {
        #expect(source.hasPrefix("// GENERATED by gamedata-gen"), "\(name)")
        #expect(!source.contains("\r"), "\(name)")
    }
}

@Test func namespaceModeWrapsEveryTypeInOneFile() throws {
    let files = try SwiftEmitter.emit(Fixtures.load().get(), namespace: "GameDataParity")
    let source = try #require(files["GameDataParity.swift"])
    #expect(files.count == 1)
    #expect(source.hasPrefix("// GENERATED by gamedata-gen"))
    #expect(source.contains("\nenum GameDataParity {\n"))
    for type in ["Good", "GoodsCatalog", "BuildingKind", "BuildingCatalog", "ProductionCatalog", "Culture", "Tech", "Age"] {
        #expect(source.contains("\n    enum \(type)"), "\(type)")
    }
    #expect(!source.contains("public "))
    #expect(!source.contains("\nextension "))
}

@Test func emitsPlantingCycles() throws {
    let extra = "items:\n  - { kind: Building, id: grove-keeper, effect: code, footprint: [2, 2], cost: 60, plantTicks: 40 }\n"
    let source = try emitted("BuildingKind+Generated.swift", from: Fixtures.withExtraPack(extra))
    #expect(source.contains("var plantTicks: UInt64? {"))
    #expect(source.contains("case .groveKeeper: 40"))
    #expect(source.contains("case .sawmill: nil"))
}

@Test func emitsMarketTerms() throws {
    let core = Fixtures.core.replacingOccurrences(of: "basePrice: 4 }", with: "basePrice: 4, market: { buy: 10, sell: 20 } }")
    let source = try emitted("Good+Generated.swift", from: Fixtures.source([("core", core), ("ages", Fixtures.ages)]))
    #expect(source.contains("public var marketTerms: MarketTerms {"))
    #expect(source.contains("case .wood: MarketTerms(buyLimit: 10, sellLimit: 20)"))
    #expect(source.contains("case .planks: MarketTerms(buyLimit: 0, sellLimit: 0)"))
}
