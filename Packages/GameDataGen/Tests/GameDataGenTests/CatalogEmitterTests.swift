import Foundation
import GameDataModel
import Testing

/// Spec: `localization` / Pack text has keys generated from the YAML.
struct CatalogEmitterTests {
    private func catalog(_ source: InMemorySource = Fixtures.source(), merging committed: Data? = nil) throws -> [String: Any] {
        let text = try CatalogEmitter.catalog(Fixtures.load(source).get(), merging: committed)
        return try #require(JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
    }

    private func entry(_ key: String, in catalog: [String: Any]) -> [String: Any]? {
        (catalog["strings"] as? [String: Any])?[key] as? [String: Any]
    }

    private func unit(_ language: String, of entry: [String: Any]?) -> [String: String]? {
        ((entry?["localizations"] as? [String: Any])?[language] as? [String: Any])?["stringUnit"] as? [String: String]
    }

    /// The fixture catalog with a reviewed German value for `good.wood.name`.
    private func withGerman(_ value: String = "Holz") throws -> Data {
        var json = try catalog()
        var strings = try #require(json["strings"] as? [String: Any])
        var wood = try #require(strings["good.wood.name"] as? [String: Any])
        var localizations = try #require(wood["localizations"] as? [String: Any])
        localizations["de"] = ["stringUnit": ["state": "translated", "value": value]]
        wood["localizations"] = localizations
        strings["good.wood.name"] = wood
        json["strings"] = strings
        return try JSONSerialization.data(withJSONObject: json)
    }

    @Test("scenario: a pack name gets a derived key")
    func packNameGetsDerivedKey() throws {
        let data = try GameDataLoader.load(from: DirectorySource(root: committedData)).get()
        let entries = CatalogEmitter.entries(data)
        #expect(entries["building.grainFarm.name"]?.english == "Grain Farm")
        #expect(entries["good.wood.unit"]?.english == "logs")
        #expect(entries["culture.eastAsian.tierName.merchants"]?.english == "Scholars")
        #expect(entries["seasonalEvent.fire.banner.warning.title"]?.english == "Dry {season} ahead")
        #expect(entries["age.medieval.blurb"] != nil)
        #expect(entries["order.crownWood.title"] != nil)
    }

    @Test("every text field of the fixture packs has a key")
    func fixtureKeys() throws {
        let entries = try CatalogEmitter.entries(Fixtures.load().get())
        #expect(entries["building.lumberjackHut.name"]?.english == "Lumberjack")
        #expect(entries["building.sawmill.name"]?.english == "Sawmill")
        #expect(entries["tier.peasants.name"]?.english == "Peasants")
        #expect(entries["good.planks.unit"]?.english == "bundles")
        #expect(entries.values.allSatisfy { !$0.comment.isEmpty })
    }

    @Test("a new catalog holds English only, in Xcode's layout")
    func newCatalog() throws {
        let text = try CatalogEmitter.catalog(Fixtures.load().get(), merging: nil)
        #expect(text.hasPrefix("{\n  \"sourceLanguage\" : \"en\",\n  \"strings\" : {\n"))
        #expect(text.hasSuffix("  },\n  \"version\" : \"1.0\"\n}\n"))
        let json = try catalog()
        #expect(unit("en", of: entry("good.wood.name", in: json)) == ["state": "translated", "value": "Wood"])
        #expect(unit("de", of: entry("good.wood.name", in: json)) == nil)
    }

    @Test("scenario: german values survive regeneration")
    func germanSurvivesRegeneration() throws {
        let committed = try withGerman()
        let json = try catalog(merging: committed)
        #expect(unit("de", of: entry("good.wood.name", in: json)) == ["state": "translated", "value": "Holz"])
        let again = try CatalogEmitter.catalog(Fixtures.load().get(), merging: Data(
            CatalogEmitter.catalog(Fixtures.load().get(), merging: committed).utf8
        ))
        #expect(try again == CatalogEmitter.catalog(Fixtures.load().get(), merging: committed))
    }

    @Test("scenario: changing english text marks german for review")
    func changedEnglishMarksGermanForReview() throws {
        let renamed = Fixtures.core.replacingOccurrences(of: "name: Wood,", with: "name: Timber,")
        let source = Fixtures.source([("core", renamed)] + Fixtures.packs.dropFirst())
        let json = try catalog(source, merging: withGerman())
        let wood = entry("good.wood.name", in: json)
        #expect(unit("en", of: wood) == ["state": "translated", "value": "Timber"])
        #expect(unit("de", of: wood) == ["state": "needs_review", "value": "Holz"])
    }

    @Test("scenario: a removed pack item drops its keys")
    func removedItemDropsKeys() throws {
        let salt = "items:\n  - { kind: Good, id: salt, name: Salt, unit: sacks, basePrice: 2, neededBy: [merchants] }\n"
        let committed = try CatalogEmitter.catalog(Fixtures.load(Fixtures.source(Fixtures.packs + [("salt", salt)])).get(), merging: nil)
        #expect(committed.contains("\"good.salt.name\""))
        let json = try catalog(merging: Data(committed.utf8))
        #expect(entry("good.salt.name", in: json) == nil)
        #expect(entry("good.wood.name", in: json) != nil)
    }

    @Test("a catalog that is not JSON fails the merge")
    func malformedCatalog() throws {
        #expect(throws: (any Error).self) {
            try CatalogEmitter.catalog(Fixtures.load().get(), merging: Data("not json".utf8))
        }
    }
}
