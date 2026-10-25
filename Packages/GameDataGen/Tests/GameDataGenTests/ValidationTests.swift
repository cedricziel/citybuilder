import GameDataModel
import Testing

@Test("scenario: unknown good in a recipe is rejected")
func unknownGoodInRecipe() {
    let core = Fixtures.core.replacingOccurrences(of: "recipe: { inputs: { wood: 1 }", with: "recipe: { inputs: { stone: 1 }")
    let errors = Fixtures.errors(Fixtures.source([("core", core), ("ages", Fixtures.ages)]))
    #expect(errors.contains { $0.contains("packs/core.yaml") && $0.contains("Building sawmill") && $0.contains("stone") })
}

@Test func unknownMaterialGoodIsRejected() {
    let core = Fixtures.core.replacingOccurrences(of: "materials: { planks: 4 }", with: "materials: { marble: 4 }")
    let errors = Fixtures.errors(Fixtures.source([("core", core), ("ages", Fixtures.ages)]))
    #expect(errors.contains { $0.contains("Building house") && $0.contains("marble") })
}

@Test("scenario: unknown house tier is rejected")
func unknownHouseTier() {
    let ages = Fixtures.ages.replacingOccurrences(of: "tier: citizens", with: "tier: nobles")
    let errors = Fixtures.errors(Fixtures.source([("core", Fixtures.core), ("ages", ages)]))
    #expect(errors.contains { $0.contains("Tech feudal-order") && $0.contains("nobles") })
}

@Test("scenario: tech prerequisite cycle is rejected")
func prerequisiteCycle() {
    let extra = """
    items:
      - { kind: Tech, id: alpha, cost: 10, age: antiquity, prerequisites: [beta] }
      - { kind: Tech, id: beta, cost: 10, age: antiquity, prerequisites: [alpha] }
    """
    let errors = Fixtures.errors(Fixtures.withExtraPack(extra))
    #expect(errors.contains { $0.contains("cycle") && $0.contains("alpha") && $0.contains("beta") })
}

@Test func unknownPrerequisiteIsRejected() {
    let extra = "items:\n  - { kind: Tech, id: alpha, cost: 10, age: antiquity, prerequisites: [omega] }\n"
    #expect(Fixtures.errors(Fixtures.withExtraPack(extra)).contains { $0.contains("Tech alpha") && $0.contains("omega") })
}

@Test("scenario: duplicate identifier is rejected")
func duplicateIdentifier() {
    let extra = "items:\n  - { kind: Building, id: sawmill, effect: code, footprint: [1, 1], cost: 1 }\n"
    let errors = Fixtures.errors(Fixtures.withExtraPack(extra))
    #expect(errors.contains { $0.contains("sawmill") && $0.contains("packs/core.yaml") && $0.contains("packs/extra.yaml") })
}

@Test func sameIdInDifferentKindsIsAllowed() {
    let extra = "items:\n  - { kind: Building, id: wood, effect: code, footprint: [1, 1], cost: 1 }\n"
    #expect(Fixtures.errors(Fixtures.withExtraPack(extra)) == [])
}

@Test func legacyIdThatShadowsAnIdIsRejected() {
    let extra = "items:\n  - { kind: Building, id: shed, effect: code, footprint: [1, 1], cost: 1, legacyIds: [sawmill] }\n"
    #expect(Fixtures.errors(Fixtures.withExtraPack(extra)).contains { $0.contains("Building shed") && $0.contains("sawmill") })
}

@Test func malformedIdIsRejected() {
    let extra = "items:\n  - { kind: Building, id: Big_Shed, effect: code, footprint: [1, 1], cost: 1 }\n"
    #expect(Fixtures.errors(Fixtures.withExtraPack(extra)).contains { $0.contains("Big_Shed") && $0.contains("hyphens") })
}

@Test("scenario: inert building is rejected")
func inertBuilding() {
    let extra = "items:\n  - { kind: Building, id: folly, footprint: [1, 1], cost: 10 }\n"
    #expect(Fixtures.errors(Fixtures.withExtraPack(extra)).contains {
        $0.contains("packs/extra.yaml") && $0.contains("Building folly") && $0.contains("inert")
    })
}

@Test func recipeWithoutOutputsNeedsCodeEffect() {
    let extra = "items:\n  - { kind: Building, id: pit, footprint: [1, 1], cost: 10, recipe: { inputs: { wood: 1 }, cycleTicks: 5 } }\n"
    #expect(Fixtures.errors(Fixtures.withExtraPack(extra)).contains { $0.contains("Building pit") && $0.contains("inert") })
}

@Test func brokenLuxuryChainIsRejected() {
    let culture = Fixtures.culture.replacingOccurrences(of: "producer: brewery }", with: "producer: sawmill }")
    let errors = Fixtures.errors(Fixtures.source([("core", Fixtures.core), ("cultures/n", culture), ("ages", Fixtures.ages)]))
    #expect(errors.contains { $0.contains("Culture northern-european") && $0.contains("sawmill") })
}

@Test func missingSignatureIsRejected() {
    let ages = Fixtures.ages.replacingOccurrences(
        of: "signature: monument, rivalResidents: 24",
        with: "signature: cathedral, rivalResidents: 24"
    )
    let errors = Fixtures.errors(Fixtures.source([("core", Fixtures.core), ("ages", ages)]))
    #expect(errors.contains { $0.contains("Age medieval") && $0.contains("cathedral") })
}

@Test func cultureSignatureMustBelongToItsCulture() {
    let culture = Fixtures.culture.replacingOccurrences(of: "signature: mead-hall", with: "signature: house")
    let errors = Fixtures.errors(Fixtures.source([("core", Fixtures.core), ("cultures/n", culture), ("ages", Fixtures.ages)]))
    #expect(errors.contains { $0.contains("Culture northern-european") && $0.contains("house") })
}

@Test func eraTechNeedsAGate() {
    let ages = Fixtures.ages.replacingOccurrences(of: "    eraGate: { tier: citizens, residents: 20 }\n", with: "")
    let errors = Fixtures.errors(Fixtures.source([("core", Fixtures.core), ("ages", ages)]))
    #expect(errors.contains { $0.contains("Tech feudal-order") && $0.contains("eraGate") })
}

@Test func unknownAgeIsRejected() {
    let extra = "items:\n  - { kind: Tech, id: alchemy, cost: 10, age: bronze }\n"
    #expect(Fixtures.errors(Fixtures.withExtraPack(extra)).contains { $0.contains("Tech alchemy") && $0.contains("bronze") })
}

@Test("scenario: reference to a later pack resolves")
func forwardReference() throws {
    let data = try Fixtures.load().get()
    let cultivation = try #require(data.techs.first { $0.id == "cultivation" })
    #expect(cultivation.age == "medieval")
    #expect(data.ages.map(\.id) == ["antiquity", "medieval"])
}

@Test func everyProblemIsReported() {
    let core = Fixtures.core
        .replacingOccurrences(of: "recipe: { inputs: { wood: 1 }", with: "recipe: { inputs: { stone: 1 }")
        .replacingOccurrences(of: "materials: { planks: 4 }", with: "materials: { marble: 4 }")
    let errors = Fixtures.errors(Fixtures.source([("core", core), ("ages", Fixtures.ages)]))
    #expect(errors.contains { $0.contains("stone") })
    #expect(errors.contains { $0.contains("marble") })
}

@Test func errorsCarryLineNumbers() {
    let core = Fixtures.core.replacingOccurrences(
        of: "outputs: { wood: 1 }, cycleTicks: 30", with: "outputs: { ash: 1 }, cycleTicks: 30"
    )
    let errors = Fixtures.errors(Fixtures.source([("core", core), ("ages", Fixtures.ages)]))
    #expect(errors.contains { $0.hasPrefix("packs/core.yaml:") && $0.contains("ash") })
}

@Test func nonPositiveCatchmentRadiusIsRejected() {
    let extra = "items:\n  - { kind: Building, id: grove-keeper, effect: code, footprint: [2, 2], cost: 60, catchmentRadius: 0 }\n"
    #expect(Fixtures.errors(Fixtures.withExtraPack(extra)).contains { $0.contains("grove-keeper") && $0.contains("catchmentRadius") })
}

@Test func plantingWithoutACatchmentIsRejected() {
    let extra = "items:\n  - { kind: Building, id: grove-keeper, effect: code, footprint: [2, 2], cost: 60, plantTicks: 40 }\n"
    #expect(Fixtures.errors(Fixtures.withExtraPack(extra)).contains { $0.contains("grove-keeper") && $0.contains("catchmentRadius") })
}

@Test func lumberjackWithoutACatchmentIsRejected() {
    // The key and the next line's indent go, so that line keeps the key's.
    let core = Fixtures.core.replacingOccurrences(of: "catchmentRadius: 2\n    ", with: "")
    let errors = Fixtures.errors(Fixtures.source([("core", core), ("ages", Fixtures.ages)]))
    #expect(errors.contains { $0.contains("lumberjack-hut") && $0.contains("catchmentRadius") })
}

@Test func nonPositivePlantTicksAreRejected() {
    let extra = "items:\n  - { kind: Building, id: grove-keeper, effect: code, footprint: [2, 2], cost: 60, plantTicks: 0 }\n"
    #expect(Fixtures.errors(Fixtures.withExtraPack(extra)).contains { $0.contains("grove-keeper") && $0.contains("plantTicks") })
}

@Test func marketLimitsDefaultToZero() throws {
    let core = Fixtures.core.replacingOccurrences(of: "basePrice: 4 }", with: "basePrice: 4, market: { sell: 20 } }")
    let data = try Fixtures.load(Fixtures.source([("core", core), ("ages", Fixtures.ages)])).get()
    #expect(data.goods.map(\.market) == [MarketLimits(buy: 0, sell: 20), MarketLimits(buy: 0, sell: 0)])
}

@Test func negativeMarketLimitIsRejected() {
    let extra = "items:\n  - { kind: Good, id: salt, name: Salt, unit: sacks, basePrice: 3, market: { buy: -1, sell: 2 } }\n"
    #expect(Fixtures.errors(Fixtures.withExtraPack(extra)).contains { $0.contains("Good salt") && $0.contains("market") })
}

@Test func unknownMarketFieldIsRejected() {
    let extra = "items:\n  - { kind: Good, id: salt, name: Salt, unit: sacks, basePrice: 3, market: { rent: 1 } }\n"
    #expect(Fixtures.errors(Fixtures.withExtraPack(extra)).contains { $0.contains("Good salt") && $0.contains("rent") })
}

// visible-distribution design D9 and #236: the distribution tunables and vehicles.

private let logisticsLine = "  - { kind: Logistics, id: logistics, haulDistance: 12, haulMinLoad: 3, haulMaxWait: 200 }\n"

private func withVehicles(_ items: String) -> InMemorySource {
    Fixtures.withExtraPack("items:\n" + items)
}

@Test func logisticsLoadsIntoTheModel() throws {
    let data = try Fixtures.load().get()
    #expect(data.logistics.map(\.haulDistance) == [12])
    #expect(data.logistics.map(\.haulMinLoad) == [3])
    #expect(data.logistics.map(\.haulMaxWait) == [200])
}

@Test func missingLogisticsIsRejected() {
    let errors = Fixtures.errors(Fixtures.withCore(Fixtures.core.replacingOccurrences(of: logisticsLine, with: "")))
    #expect(errors.contains { $0.contains("no logistics") })
}

@Test func secondLogisticsItemIsRejected() {
    let errors = Fixtures.errors(withVehicles("  - { kind: Logistics, id: more, haulDistance: 5, haulMinLoad: 2, haulMaxWait: 9 }\n"))
    #expect(errors.contains { $0.contains("Logistics more") && $0.contains("second") })
}

@Test func nonPositiveLogisticsValueIsRejected() {
    let core = Fixtures.core.replacingOccurrences(
        of: logisticsLine,
        with: logisticsLine.replacingOccurrences(of: "haulDistance: 12", with: "haulDistance: 0")
    )
    #expect(Fixtures.errors(Fixtures.withCore(core)).contains { $0.contains("`haulDistance` must be at least 1") })
}

@Test(arguments: [
    ("  - { kind: Vehicle, id: cart, age: bronze, capacity: 4 }\n", "unknown age `bronze`"),
    ("  - { kind: Vehicle, id: cart, age: medieval, capacity: 2 }\n", "`capacity` must hold the `haulMinLoad` of 3"),
    (
        "  - { kind: Vehicle, id: cart, age: medieval, capacity: 4 }\n  - { kind: Vehicle, id: wagon, age: medieval, capacity: 6 }\n",
        "age `medieval` already has vehicle `cart`"
    )
])
func invalidVehiclesAreRejected(items: String, message: String) {
    #expect(Fixtures.errors(withVehicles(items)).contains { $0.contains(message) })
}

@Test func vehiclesEmitTheirAgeAndCapacity() throws {
    let data = try Fixtures.load(withVehicles("  - { kind: Vehicle, id: cart, age: medieval, capacity: 4 }\n")).get()
    let source = try #require(SwiftEmitter.emit(data)["Logistics+Generated.swift"])
    #expect(source.contains("public static let haulDistance = 12"))
    #expect(source.contains("public enum Vehicle: String, CaseIterable, Codable, Hashable, Sendable"))
    #expect(source.contains("case .cart: .medieval"))
    #expect(source.contains("case .cart: 4"))
}
