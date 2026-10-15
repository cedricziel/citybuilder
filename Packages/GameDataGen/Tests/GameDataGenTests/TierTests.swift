import GameDataModel
import Testing

// Scenarios from openspec/changes/tier-needs-data (game-data-catalog).

@Test("scenario: tier order is case order")
func tierOrderIsCaseOrder() throws {
    let data = try Fixtures.load().get()
    #expect(data.tiers.map(\.id) == ["peasants", "citizens", "merchants"])
    #expect(data.tiers.map(\.capacity) == [4, 6, 8])
    #expect(data.tiers.map(\.taxPerResident) == [1, 2, 4])
}

@Test("scenario: unknown tier in neededBy is rejected")
func unknownTierInNeededBy() {
    let extra = "items:\n  - { kind: Good, id: cloth, name: Cloth, unit: bolts, basePrice: 9, neededBy: [nobles] }\n"
    let errors = Fixtures.errors(Fixtures.withExtraPack(extra))
    #expect(errors.contains { $0.contains("packs/extra.yaml") && $0.contains("Good cloth") && $0.contains("nobles") })
}

@Test("scenario: need listed twice is rejected")
func needListedTwice() {
    let core = Fixtures.core.replacingOccurrences(
        of: "{ kind: Good, id: wood, name: Wood, unit: logs, basePrice: 4 }",
        with: "{ kind: Good, id: wood, name: Wood, unit: logs, basePrice: 4, neededBy: [merchants] }"
    )
    let errors = Fixtures.errors(Fixtures.withCore(core))
    #expect(errors.contains { $0.contains("Good wood") && $0.contains("merchants") && $0.contains("already") })
}

@Test func needOfUnknownGoodIsRejected() {
    let core = Fixtures.core.replacingOccurrences(of: "needs: [planks, wood]", with: "needs: [planks, silk]")
    let errors = Fixtures.errors(Fixtures.withCore(core))
    #expect(errors.contains { $0.contains("Tier merchants") && $0.contains("silk") })
}

@Test func tierNumbersAreChecked() {
    let core = Fixtures.core.replacingOccurrences(of: "capacity: 4, taxPerResident: 1", with: "capacity: 0, taxPerResident: -1")
    let errors = Fixtures.errors(Fixtures.withCore(core))
    #expect(errors.contains { $0.contains("Tier peasants") && $0.contains("`capacity`") })
    #expect(errors.contains { $0.contains("Tier peasants") && $0.contains("`taxPerResident`") })
}

@Test("scenario: culture name for an undeclared tier is rejected")
func cultureNameForUndeclaredTier() {
    let culture = Fixtures.culture.replacingOccurrences(of: "merchants: Merchants", with: "nobles: Nobles")
    let errors = Fixtures.errors(Fixtures.withCulture(culture))
    #expect(errors.contains { $0.contains("Culture northern-european") && $0.contains("nobles") })
}

@Test("scenario: every good has a consumer")
func everyGoodHasAConsumer() throws {
    let data = try Fixtures.load().get()
    #expect(data.goods.map(\.id) == ["wood", "planks", "hops", "beer"])
}

@Test("scenario: good without a consumer is rejected")
func goodWithoutAConsumer() {
    let extra = "items:\n  - { kind: Good, id: cloth, name: Cloth, unit: bolts, basePrice: 9 }\n"
    let errors = Fixtures.errors(Fixtures.withExtraPack(extra))
    #expect(errors.contains { $0.contains("packs/extra.yaml") && $0.contains("Good cloth") && $0.contains("consumer") })
}

@Test("scenario: a tier need is a consumer")
func aTierNeedIsAConsumer() {
    let extra = "items:\n  - { kind: Good, id: cloth, name: Cloth, unit: bolts, basePrice: 9, neededBy: [citizens] }\n"
    #expect(Fixtures.errors(Fixtures.withExtraPack(extra)) == [])
}

@Test("scenario: pack adds a need to an existing tier")
func packAddsANeedToAnExistingTier() throws {
    let extra = "items:\n  - { kind: Good, id: cloth, name: Cloth, unit: bolts, basePrice: 9, neededBy: [merchants] }\n"
    let data = try Fixtures.load(Fixtures.withExtraPack(extra)).get()
    #expect(data.tiers.map(\.needs) == [["planks"], ["planks"], ["planks", "wood", "cloth"]])
}

@Test("scenario: added needs follow load order")
func addedNeedsFollowLoadOrder() throws {
    let first = "items:\n  - { kind: Good, id: cloth, name: Cloth, unit: bolts, basePrice: 9, neededBy: [citizens] }\n"
    let second = "items:\n  - { kind: Good, id: salt, name: Salt, unit: sacks, basePrice: 3, neededBy: [citizens] }\n"
    let data = try Fixtures.load(Fixtures.source(Fixtures.packs + [("second", second), ("first", first)])).get()
    #expect(data.tiers[1].needs == ["planks", "salt", "cloth"])
}

@Test("scenario: culture without tier names uses the tier's names")
func cultureWithoutTierNames() throws {
    let culture = Fixtures.culture.replacingOccurrences(
        of: "    tiers: { peasants: Peasants, citizens: Citizens, merchants: Merchants }\n", with: ""
    )
    let data = try Fixtures.load(Fixtures.withCulture(culture)).get()
    let northern = try #require(data.cultures.first)
    #expect(data.tiers.map(northern.tierName) == ["Peasants", "Citizens", "Merchants"])
}

@Test("scenario: culture overrides one tier name")
func cultureOverridesOneTierName() throws {
    let culture = Fixtures.culture.replacingOccurrences(
        of: "tiers: { peasants: Peasants, citizens: Citizens, merchants: Merchants }", with: "tiers: { merchants: Jarls }"
    )
    let data = try Fixtures.load(Fixtures.withCulture(culture)).get()
    let northern = try #require(data.cultures.first)
    #expect(data.tiers.map(northern.tierName) == ["Peasants", "Citizens", "Jarls"])
}

@Test func emitsHouseTierWithPositionalRawValues() throws {
    let extra = "items:\n  - { kind: Good, id: cloth, name: Cloth, unit: bolts, basePrice: 9, neededBy: [merchants] }\n"
    let source = try emitted("HouseTier+Generated.swift", from: Fixtures.withExtraPack(extra))
    #expect(source.contains("public enum HouseTier: UInt8, CaseIterable, Codable, Sendable {\n"))
    #expect(source.contains("    case peasants = 1\n    case citizens = 2\n    case merchants = 3\n"))
    #expect(source.contains("public var capacity: UInt32 {"))
    #expect(source.contains("case .citizens: 6"))
    #expect(source.contains("public var needs: [Good] {"))
    #expect(source.contains("case .merchants: [.planks, .wood, .cloth]"))
    #expect(source.contains("public var taxPerResident: Int64 {"))
    #expect(source.contains("case .merchants: 4"))
    #expect(source.contains("case .peasants: \"Peasants\""))
}

@Test func emitsTierNamesWithTheTiersOwnNameAsFallback() throws {
    let culture = Fixtures.culture.replacingOccurrences(
        of: "tiers: { peasants: Peasants, citizens: Citizens, merchants: Merchants }", with: "tiers: { merchants: Jarls }"
    )
    let source = try emitted("Culture+Generated.swift", from: Fixtures.withCulture(culture))
    #expect(source.contains("case (.northernEuropean, .peasants): \"Peasants\""))
    #expect(source.contains("case (.northernEuropean, .merchants): \"Jarls\""))
}
