import Foundation
import GameDataModel
import Testing

private func scratch() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("gamedata-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func write(_ source: InMemorySource, to root: URL) throws {
    for (path, text) in source.files {
        let file = root.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: file, atomically: true, encoding: .utf8)
    }
}

private func contents(of directory: URL) throws -> [String: Data] {
    let names = try FileManager.default.contentsOfDirectory(atPath: directory.path)
    return try Dictionary(uniqueKeysWithValues: names.map { name in
        try (name, Data(contentsOf: directory.appendingPathComponent(name)))
    })
}

@Test("scenario: two runs produce identical output")
func twoRunsProduceIdenticalOutput() throws {
    let data = try scratch(), first = try scratch(), second = try scratch()
    try write(Fixtures.source(), to: data)
    _ = try Generator.generate(dataDirectory: data, outputDirectory: first).get()
    _ = try Generator.generate(dataDirectory: data, outputDirectory: second).get()
    let firstFiles = try contents(of: first)
    #expect(!firstFiles.isEmpty)
    #expect(try firstFiles == contents(of: second))
}

@Test(arguments: [nil, "GameDataParity"])
func generateWritesEveryEmittedFile(namespace: String?) throws {
    let data = try scratch(), out = try scratch()
    try write(Fixtures.source(), to: data)
    let written = try Generator.generate(dataDirectory: data, outputDirectory: out, namespace: namespace).get()
    #expect(try written == SwiftEmitter.emit(Fixtures.load().get(), namespace: namespace).keys.sorted())
    #expect(try contents(of: out).keys.sorted() == written)
}

@Test func generateWritesNothingWhenValidationFails() throws {
    let data = try scratch(), out = try scratch()
    try write(Fixtures.source(extraFiles: ["packs/stray.yaml": "items: []\n"]), to: data)
    let result = Generator.generate(dataDirectory: data, outputDirectory: out)
    #expect(throws: GameDataErrors.self) { try result.get() }
    #expect(try contents(of: out).isEmpty)
}

@Test func generateRemovesStaleGeneratedFilesOnly() throws {
    let data = try scratch(), out = try scratch()
    try write(Fixtures.source(), to: data)
    try (SwiftEmitter.banner + "enum Gone {}\n").write(to: out.appendingPathComponent("Gone.swift"), atomically: true, encoding: .utf8)
    try "enum Mine {}\n".write(to: out.appendingPathComponent("Mine.swift"), atomically: true, encoding: .utf8)
    let written = try Generator.generate(dataDirectory: data, outputDirectory: out).get()
    #expect(try contents(of: out).keys.sorted() == (written + ["Mine.swift"]).sorted())
}
