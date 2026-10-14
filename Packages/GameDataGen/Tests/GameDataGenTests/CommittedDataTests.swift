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
