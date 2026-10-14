import Foundation
import GameDataModel
import Testing

/// `Packages/CityCore/GameData`, the committed manifest, packs and schemas.
let committedData = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().appendingPathComponent("CityCore/GameData")

private func schema(_ name: String) throws -> [String: Any] {
    let data = try Data(contentsOf: committedData.appendingPathComponent("schema/\(name)"))
    return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
}

/// The `then` branch of the pack schema's item that applies to `kind`.
private func branch(for kind: String, in item: [String: Any]) throws -> [String: Any] {
    let branches = try #require(item["allOf"] as? [[String: Any]])
    let match = branches.first { branch in
        let condition = branch["if"] as? [String: Any]
        let properties = condition?["properties"] as? [String: Any]
        return (properties?["kind"] as? [String: Any])?["const"] as? String == kind
    }
    return try #require(match?["then"] as? [String: Any], "no branch for \(kind)")
}

@Test func committedPacksAreValid() {
    let result = GameDataLoader.load(from: DirectorySource(root: committedData))
    if case let .failure(errors) = result {
        Issue.record("\(errors)")
    }
}

@Test("scenario: schema and decoder agree")
func schemaAndDecoderAgree() throws {
    let pack = try schema("pack.schema.json")
    let item = try #require((pack["$defs"] as? [String: Any])?["item"] as? [String: Any])
    let kinds = try #require((item["properties"] as? [String: Any])?["kind"] as? [String: Any])
    #expect(Set(kinds["enum"] as? [String] ?? []) == Set(ItemSchema.kinds.keys))
    for (kind, fields) in ItemSchema.kinds {
        let then = try branch(for: kind, in: item)
        let required = Set(then["required"] as? [String] ?? [])
        let allowed = Set((then["properties"] as? [String: Any])?.keys.map(\.self) ?? [])
        #expect(required == fields.required.union(["kind"]), "\(kind) required")
        #expect(allowed == fields.allowed, "\(kind) allowed")
        #expect(then["additionalProperties"] as? Bool == false, "\(kind) additionalProperties")
    }
}

@Test func manifestSchemaListsTheManifestFields() throws {
    let index = try schema("index.schema.json")
    let properties = try #require(index["properties"] as? [String: Any])
    #expect(Set(properties.keys) == ["schemaVersion", "packs"])
    #expect(Set(index["required"] as? [String] ?? []) == ["schemaVersion", "packs"])
}

/// `Packages/CityCore/Sources/CityCore`.
private let cityCoreSources = committedData.deletingLastPathComponent().appendingPathComponent("Sources/CityCore")

@Test("scenario: every catalog entry comes from the packs")
func everyCatalogEntryComesFromThePacks() throws {
    let data = try GameDataLoader.load(from: DirectorySource(root: committedData)).get()
    let generated = cityCoreSources.appendingPathComponent("Generated")
    let committed = try FileManager.default.contentsOfDirectory(atPath: generated.path).filter { $0.hasSuffix(".swift") }
    let emitted = SwiftEmitter.emit(data)
    #expect(committed.sorted() == emitted.keys.sorted())
    for (name, source) in emitted {
        #expect(try String(contentsOf: generated.appendingPathComponent(name), encoding: .utf8) == source, "\(name)")
    }

    let files = FileManager.default.enumerator(atPath: cityCoreSources.path)?.compactMap { $0 as? String } ?? []
    let handWritten = files.filter { $0.hasSuffix(".swift") && !$0.hasPrefix("Generated/") }
    #expect(!handWritten.isEmpty)
    for file in handWritten {
        let source = try String(contentsOf: cityCoreSources.appendingPathComponent(file), encoding: .utf8)
        let declaration = source.firstMatch(of: /\benum\s+(Good|BuildingKind|Culture|Tech|Age)\b/)
        #expect(declaration == nil, "\(file) declares a content enum")
    }
}

@Test func fixturePackValidatesWithTheCommittedPacks() throws {
    let fixture = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Fixtures/fixture-pack.yaml")
    var files = try ["packs/fixture.yaml": String(contentsOf: fixture, encoding: .utf8)]
    let source = DirectorySource(root: committedData)
    files["index.yaml"] = try #require(source.read("index.yaml")) + "  - fixture\n"
    for pack in source.packFiles() {
        files[pack] = source.read(pack)
    }
    let data = try GameDataLoader.load(from: InMemorySource(files: files)).get()
    #expect(data.cultures.last?.id == "andean")
    #expect(data.ages.last?.id == "space")
}
