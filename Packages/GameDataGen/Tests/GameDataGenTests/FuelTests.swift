import GameDataModel
import Testing

// add-event-counterplay D7: a building may burn a good on an interval, which
// counts as the good's consumer.

private let physician = """
items:
  - { kind: Good, id: herbs, name: Herbs, unit: bunches, basePrice: 5 }
  - kind: Building
    id: physician
    effect: code
    footprint: [2, 2]
    cost: 90
    storage: 8
    fuel: { good: herbs, amount: 1, everyTicks: 100 }
"""

@Test("scenario: a building's fuel is game data and consumes its good")
func fuelIsEmitted() throws {
    let source = try emitted("BuildingKind+Generated.swift", from: Fixtures.withExtraPack(physician))
    #expect(source.contains("public var packFuel: FuelSpec? {"))
    #expect(source.contains("case .physician: FuelSpec(good: .herbs, amount: 1, intervalTicks: 100)"))
    #expect(source.contains("case .house: nil"))
}

@Test func fuelNamesAKnownGoodAndAPositiveBurn() {
    let bad = physician.replacingOccurrences(of: "good: herbs, amount: 1, everyTicks: 100", with: "good: silk, amount: 0, everyTicks: 0")
    let errors = Fixtures.errors(Fixtures.withExtraPack(bad))
    #expect(errors.contains { $0.contains("Building physician") && $0.contains("silk") }, "\(errors)")
    #expect(errors.contains { $0.contains("Building physician") && $0.contains("`fuel`") && $0.contains("positive") }, "\(errors)")
}
