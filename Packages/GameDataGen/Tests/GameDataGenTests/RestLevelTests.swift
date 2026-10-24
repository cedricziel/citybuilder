import Testing
@testable import GameDataModel

// goods-and-production / Producers rest while the stores hold plenty
// (openspec/changes/rest-when-stocked): the `restAt` field on goods.

private func core(planks: String) -> String {
    Fixtures.core.replacingOccurrences(
        of: "{ kind: Good, id: planks, name: Planks, unit: bundles, basePrice: 8 }",
        with: "{ kind: Good, id: planks, name: Planks, unit: bundles, basePrice: 8\(planks) }"
    )
}

@Test func restLevelIsEmitted() throws {
    let source = Fixtures.source([("core", core(planks: ", restAt: 40")), ("ages", Fixtures.ages)])
    let good = try emitted("Good+Generated.swift", from: source)
    #expect(good.contains("case .planks: 40"))
    #expect(good.contains("case .wood: nil"))
}

@Test func restLevelMustBePositive() {
    let source = Fixtures.source([("core", core(planks: ", restAt: 0")), ("ages", Fixtures.ages)])
    #expect(Fixtures.errors(source).contains { $0.contains("Good planks") && $0.contains("restAt") })
}
