import GameDataModel
import Testing

// buildings-and-construction / Granary (openspec/changes/add-event-counterplay):
// a store may name the goods it accepts.

private func core(accepting goods: String, storage: String = "storagePerGood: 60") -> String {
    Fixtures.core.replacingOccurrences(of: "storage: 8\n", with: "\(storage)\n    accepts: \(goods)\n")
}

@Test func acceptsIsEmitted() throws {
    let source = try emitted("BuildingKind+Generated.swift", from: Fixtures.withCore(core(accepting: "[wood, planks]")))
    #expect(source.contains("public var accepts: Set<Good>? {"))
    #expect(source.contains("case .house: [.planks, .wood]"))
    #expect(source.contains("case .sawmill: nil"))
}

@Test func acceptsNamesKnownGoods() {
    let errors = Fixtures.errors(Fixtures.withCore(core(accepting: "[silk]")))
    #expect(errors.contains { $0.contains("Building house") && $0.contains("silk") }, "\(errors)")
}

@Test func acceptsNeedsAStore() {
    let errors = Fixtures.errors(Fixtures.withCore(core(accepting: "[wood]", storage: "storage: 8")))
    #expect(errors.contains { $0.contains("Building house") && $0.contains("`accepts`") }, "\(errors)")
}
