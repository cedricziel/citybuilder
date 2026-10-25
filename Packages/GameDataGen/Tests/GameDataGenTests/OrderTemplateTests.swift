import GameDataModel
import Testing

// Scenarios from openspec/changes/add-orders (orders / Order templates are game data).

private let templates = """
items:
  - kind: Order
    id: crown-timber
    issuer: crown
    good: planks
    title: Timber for the fleet
    text: The crown is building ships and wants planks.
    seasons: 2
    size: 90
    min: 12
    max: 80
    reward: 125
  - kind: Order
    id: rival-wood
    issuer: rival
    good: wood
    title: Wood for a neighbour
    text: A neighbour is short of wood.
    minAge: medieval
    seasons: 3
    size: 70
    min: 15
    max: 80
    reward: 40
    favour: 3
    penalty: 1
"""

@Test("scenario: built-in order templates load")
func orderTemplatesLoad() throws {
    let data = try Fixtures.load(Fixtures.withExtraPack(templates)).get()
    #expect(data.orders.map(\.id) == ["crown-timber", "rival-wood"])
    let timber = data.orders[0]
    #expect(timber.issuer == "crown" && timber.good == "planks" && timber.seasons == 2)
    #expect(timber.size == 90 && timber.min == 12 && timber.max == 80 && timber.reward == 125)
    #expect(timber.minAge == nil && timber.favour == 2 && timber.penalty == 2)
    let rival = data.orders[1]
    #expect(rival.minAge == "medieval" && rival.favour == 3 && rival.penalty == 1)
}

@Test("scenario: age order cadence defaults to four seasons")
func ageOrderEveryDefaults() throws {
    let ages = Fixtures.ages.replacingOccurrences(of: "rivalResidents: 24 }", with: "rivalResidents: 24, orderEvery: 3 }")
    let data = try Fixtures.load(Fixtures.source([("core", Fixtures.core), ("ages", ages)])).get()
    #expect(data.ages.map(\.orderEvery) == [4, 3])
}

@Test("scenario: unknown good in an order template is rejected")
func unknownGoodInOrderTemplate() {
    let bad = templates.replacingOccurrences(of: "good: planks", with: "good: silk")
    let errors = Fixtures.errors(Fixtures.withExtraPack(bad))
    #expect(errors.contains { $0.contains("Order crown-timber") && $0.contains("silk") }, "\(errors)")
}

@Test("scenario: order template bounds are enforced")
func orderTemplateBounds() {
    let bad = templates
        .replacingOccurrences(of: "seasons: 2", with: "seasons: 0")
        .replacingOccurrences(of: "min: 12", with: "min: 90")
        .replacingOccurrences(
            of: "text: The crown is building ships and wants planks.",
            with: "text: \(String(repeating: "x", count: 101))"
        )
        .replacingOccurrences(of: "issuer: rival", with: "issuer: mainland")
    let errors = Fixtures.errors(Fixtures.withExtraPack(bad))
    #expect(errors.contains { $0.contains("Order crown-timber") && $0.contains("`seasons`") }, "\(errors)")
    #expect(errors.contains { $0.contains("Order crown-timber") && $0.contains("`min`") }, "\(errors)")
    #expect(errors.contains { $0.contains("Order crown-timber") && $0.contains("`text`") }, "\(errors)")
    #expect(errors.contains { $0.contains("Order rival-wood") && $0.contains("`issuer`") }, "\(errors)")
}

@Test("scenario: unknown age in an order template is rejected")
func unknownAgeInOrderTemplate() {
    let bad = templates.replacingOccurrences(of: "minAge: medieval", with: "minAge: stone")
    let errors = Fixtures.errors(Fixtures.withExtraPack(bad))
    #expect(errors.contains { $0.contains("Order rival-wood") && $0.contains("stone") }, "\(errors)")
}

@Test func orderRewardsAndSizesAreChecked() {
    let bad = templates
        .replacingOccurrences(of: "size: 90", with: "size: 301")
        .replacingOccurrences(of: "reward: 125", with: "reward: 501")
        .replacingOccurrences(of: "favour: 3", with: "favour: -1")
    let errors = Fixtures.errors(Fixtures.withExtraPack(bad))
    #expect(errors.contains { $0.contains("`size`") }, "\(errors)")
    #expect(errors.contains { $0.contains("`reward`") }, "\(errors)")
    #expect(errors.contains { $0.contains("`favour`") }, "\(errors)")
}

@Test func duplicateOrderIdsAreRejected() {
    let bad = templates + "\n" + templates.replacingOccurrences(of: "items:\n", with: "")
    let errors = Fixtures.errors(Fixtures.withExtraPack(bad))
    #expect(errors.contains { $0.contains("duplicate Order id") }, "\(errors)")
}

@Test func emitsOrderTemplates() throws {
    let source = try emitted("OrderTemplate+Generated.swift", from: Fixtures.withExtraPack(templates))
    #expect(source.contains("public enum OrderTemplate: String, CaseIterable, Codable, Sendable {"))
    #expect(source.contains("    case crownTimber = \"crown-timber\"\n"))
    #expect(source.contains("case .crownTimber: .crown"))
    #expect(source.contains("case .rivalWood: .planks") == false)
    #expect(source.contains("case .rivalWood: .wood"))
    #expect(source.contains("case .rivalWood: .medieval"))
    #expect(source.contains("case .crownTimber: nil"))
}
