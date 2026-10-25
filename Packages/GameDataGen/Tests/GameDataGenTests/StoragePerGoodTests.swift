import Testing
@testable import GameDataModel

// warehouses-and-logistics / Goods buffer storage
// (openspec/changes/per-good-storage): the `storagePerGood` building field.

/// The fixture's house with its `storage: 8` line replaced by `fields`,
/// each indented like it.
private func core(houseStorage fields: [String]) -> String {
    let lines = Fixtures.core.components(separatedBy: "\n")
    guard let index = lines.firstIndex(where: { $0.hasSuffix("storage: 8") }) else { return Fixtures.core }
    let indent = String(lines[index].prefix { $0 == " " })
    return (lines[..<index] + fields.map { indent + $0 } + lines[(index + 1)...]).joined(separator: "\n")
}

@Test func storagePerGoodIsEmitted() throws {
    let source = Fixtures.source([("core", core(houseStorage: ["storagePerGood: 40"])), ("ages", Fixtures.ages)])
    let building = try emitted("BuildingKind+Generated.swift", from: source)
    #expect(building.contains("case .house: 40"))
    #expect(building.contains("case .lumberjackHut: nil"))
}

@Test func storagePerGoodMustBePositive() {
    let source = Fixtures.source([("core", core(houseStorage: ["storagePerGood: 0"])), ("ages", Fixtures.ages)])
    #expect(Fixtures.errors(source).contains { $0.contains("storagePerGood") && $0.contains("positive") })
}

@Test func storageAndStoragePerGoodExcludeEachOther() {
    let source = Fixtures.source([("core", core(houseStorage: ["storage: 8", "storagePerGood: 40"])), ("ages", Fixtures.ages)])
    #expect(Fixtures.errors(source).contains { $0.contains("not both") })
}
