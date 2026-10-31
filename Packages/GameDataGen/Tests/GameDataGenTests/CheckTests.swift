import Foundation
import GameDataModel
import Testing

/// Packs and an output directory generated from them.
private func generated() throws -> (data: URL, out: URL) {
    let data = try scratch(), out = try scratch()
    try write(Fixtures.source(), to: data)
    _ = try Generator.generate(dataDirectory: data, outputDirectory: out).get()
    return (data, out)
}

@Test("scenario: up-to-date output passes the check")
func upToDateOutputPassesTheCheck() throws {
    let (data, out) = try generated()
    #expect(try Generator.check(dataDirectory: data, outputDirectory: out).get() == [])
}

@Test("scenario: stale generated output fails the check")
func staleGeneratedOutputFailsTheCheck() throws {
    let (data, out) = try generated()
    let core = data.appendingPathComponent("packs/core.yaml")
    try String(contentsOf: core, encoding: .utf8).replacingOccurrences(of: "basePrice: 4", with: "basePrice: 5")
        .write(to: core, atomically: true, encoding: .utf8)
    let drift = try Generator.check(dataDirectory: data, outputDirectory: out).get()
    #expect(drift == ["Good+Generated.swift differs"])
}

@Test func checkNamesMissingAndLeftoverFiles() throws {
    let (data, out) = try generated()
    try FileManager.default.removeItem(at: out.appendingPathComponent("Age+Generated.swift"))
    try (SwiftEmitter.banner + "enum Gone {}\n").write(to: out.appendingPathComponent("Gone.swift"), atomically: true, encoding: .utf8)
    try "enum Mine {}\n".write(to: out.appendingPathComponent("Mine.swift"), atomically: true, encoding: .utf8)
    let drift = try Generator.check(dataDirectory: data, outputDirectory: out).get()
    #expect(drift == ["Age+Generated.swift is missing", "Gone.swift is no longer generated"])
}

@Test func checkWritesNothing() throws {
    let (data, out) = try generated()
    let before = try contents(of: out)
    let core = data.appendingPathComponent("packs/core.yaml")
    try String(contentsOf: core, encoding: .utf8).replacingOccurrences(of: "basePrice: 4", with: "basePrice: 5")
        .write(to: core, atomically: true, encoding: .utf8)
    _ = Generator.check(dataDirectory: data, outputDirectory: out)
    #expect(try contents(of: out) == before)
}

@Test func checkReportsInvalidPacks() throws {
    let (data, out) = try generated()
    try "items: []\n".write(to: data.appendingPathComponent("packs/stray.yaml"), atomically: true, encoding: .utf8)
    #expect(throws: GameDataErrors.self) { try Generator.check(dataDirectory: data, outputDirectory: out).get() }
}

@Test("generate writes the catalog and keeps its German; check compares it")
func catalogIsGeneratedAndChecked() throws {
    let data = try scratch(), out = try scratch(), catalog = try scratch().appendingPathComponent("GameData.xcstrings")
    try write(Fixtures.source(), to: data)
    _ = try Generator.generate(dataDirectory: data, outputDirectory: out, catalogFile: catalog).get()
    let english = try String(contentsOf: catalog, encoding: .utf8)
    #expect(english.contains("\"good.wood.name\""))
    #expect(try Generator.check(dataDirectory: data, outputDirectory: out, catalogFile: catalog).get() == [])

    var json = try #require(JSONSerialization.jsonObject(with: Data(english.utf8)) as? [String: Any])
    var strings = try #require(json["strings"] as? [String: Any])
    strings["good.wood.name"] = ["localizations": [
        "en": ["stringUnit": ["state": "translated", "value": "Wood"]],
        "de": ["stringUnit": ["state": "translated", "value": "Holz"]]
    ]]
    json["strings"] = strings
    try JSONSerialization.data(withJSONObject: json).write(to: catalog)
    _ = try Generator.generate(dataDirectory: data, outputDirectory: out, catalogFile: catalog).get()
    let german = try String(contentsOf: catalog, encoding: .utf8)
    #expect(german.contains("\"value\" : \"Holz\""))
    #expect(try Generator.check(dataDirectory: data, outputDirectory: out, catalogFile: catalog).get() == [])

    try english.replacingOccurrences(of: "\"Wood\"", with: "\"Timber\"").write(to: catalog, atomically: true, encoding: .utf8)
    #expect(try Generator.check(dataDirectory: data, outputDirectory: out, catalogFile: catalog).get() == ["GameData.xcstrings differs"])
    try FileManager.default.removeItem(at: catalog)
    #expect(try Generator.check(dataDirectory: data, outputDirectory: out, catalogFile: catalog).get() == ["GameData.xcstrings is missing"])
}

@Test func catalogPathIsAnOption() throws {
    let data = try scratch(), out = try scratch(), catalog = try scratch().appendingPathComponent("Scratch.xcstrings")
    try write(Fixtures.source(), to: data)
    let outcome = GameDataCommand.run(
        ["generate", "--data", data.path, "--out", out.path, "--catalog", catalog.path],
        standardInput: { Data() }, currentDirectory: data
    )
    #expect(outcome.status == 0)
    #expect(FileManager.default.fileExists(atPath: catalog.path))
}
