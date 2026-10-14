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
