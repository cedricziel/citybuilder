import GameDataModel
import Testing

@Test func baseFixtureIsValid() {
    #expect(Fixtures.errors(Fixtures.source()) == [])
}

@Test("scenario: shared defaults through anchors and merge keys")
func mergeKeys() throws {
    let data = try Fixtures.load().get()
    let sawmill = try #require(data.buildings.first { $0.id == "sawmill" })
    #expect(sawmill.cost == 120)
    #expect(sawmill.buildTicks == 30)
    #expect(sawmill.upkeep == 2)
}

@Test("scenario: unknown field is rejected")
func unknownField() {
    let core = Fixtures.core.replacingOccurrences(of: "storage: 16", with: "storage: 16\n    colour: red")
    let errors = Fixtures.errors(Fixtures.source([("core", core), ("ages", Fixtures.ages)]))
    #expect(errors.contains {
        $0.contains("packs/core.yaml") && $0.contains("lumberjack-hut") && $0.contains("colour")
    })
}

@Test func unknownNestedFieldIsRejected() {
    let core = Fixtures.core.replacingOccurrences(of: "cycleTicks: 25 }", with: "cycleTicks: 25, speed: 2 }")
    let errors = Fixtures.errors(Fixtures.source([("core", core), ("ages", Fixtures.ages)]))
    #expect(errors.contains { $0.contains("sawmill") && $0.contains("speed") })
}

@Test func unknownKindIsRejected() {
    let extra = "items:\n  - { kind: Spaceship, id: ark }\n"
    let errors = Fixtures.errors(Fixtures.withExtraPack(extra))
    #expect(errors.contains { $0.contains("packs/extra.yaml") && $0.contains("Spaceship") })
}

@Test func implicitlyTypedStringIsRejected() {
    let extra = "items:\n  - { kind: Good, id: no, name: No, unit: sacks, basePrice: 3 }\n"
    let errors = Fixtures.errors(Fixtures.withExtraPack(extra))
    #expect(errors.contains { $0.contains("`id`") && $0.contains("quote") })
}

@Test func quotedStringIsAccepted() throws {
    let extra = """
    items:
      - { kind: Good, id: "no", name: "1.10", unit: sacks, basePrice: 3 }
      - kind: Building
        id: no-mill
        footprint: [1, 1]
        cost: 1
        recipe: { inputs: { "no": 1 }, outputs: { wood: 1 }, cycleTicks: 10 }
    """
    let data = try Fixtures.load(Fixtures.withExtraPack(extra)).get()
    let good = try #require(data.goods.first { $0.id == "no" })
    #expect(good.name == "1.10")
}

@Test func wrongScalarTypeIsRejected() {
    let core = Fixtures.core.replacingOccurrences(of: "cost: 80", with: "cost: lots")
    let errors = Fixtures.errors(Fixtures.source([("core", core), ("ages", Fixtures.ages)]))
    #expect(errors.contains { $0.contains("lumberjack-hut") && $0.contains("`cost`") })
}

@Test(arguments: ItemSchema.kinds.keys.sorted())
func decoderRequiresExactlyTheSchemaRequiredFields(kind: String) throws {
    let schema = try #require(ItemSchema.kinds[kind])
    for missing in schema.required.sorted() where missing != "id" {
        let item = Fixtures.minimalItems[kind, default: [:]].filter { $0.key != missing }
        let errors = Fixtures.errors(Fixtures.withExtraPack(Fixtures.pack([item.merging(["kind": kind]) { $1 }])))
        #expect(errors.contains { $0.contains("missing required field `\(missing)`") }, "\(kind) without \(missing)")
    }
    let minimal = Fixtures.minimalItems[kind, default: [:]]
    #expect(Set(minimal.keys) == schema.required)
}

@Test(arguments: ItemSchema.kinds.keys.sorted())
func decoderAcceptsEveryOptionalSchemaField(kind: String) throws {
    let schema = try #require(ItemSchema.kinds[kind])
    let optional = Fixtures.optionalFields[kind, default: [:]]
    #expect(Set(optional.keys) == schema.optional)
    let item = Fixtures.minimalItems[kind, default: [:]].merging(optional) { $1 }.merging(["kind": kind]) { $1 }
    let errors = Fixtures.errors(Fixtures.withExtraPack(Fixtures.pack([item])))
    #expect(!errors.contains { $0.contains("unknown field") || $0.contains("missing required field") }, "\(errors)")
}

@Test("scenario: unlisted pack file is rejected")
func unlistedPackFileIsRejected() {
    let source = Fixtures.source(extraFiles: ["packs/forgotten.yaml": "items: []\n"])
    #expect(Fixtures.errors(source).contains { $0.contains("packs/forgotten.yaml") && $0.contains("manifest") })
}

@Test func unlistedPackFileInSubdirectoryIsRejected() {
    let source = Fixtures.source(extraFiles: ["packs/cultures/forgotten.yaml": "items: []\n"])
    #expect(Fixtures.errors(source).contains { $0.contains("packs/cultures/forgotten.yaml") })
}

@Test func manifestEntryWithoutFileIsRejected() {
    var source = Fixtures.source()
    source.files["index.yaml", default: ""] += "  - missing\n"
    #expect(Fixtures.errors(source).contains { $0.contains("packs/missing.yaml") })
}

@Test func manifestEntryListedTwiceIsRejected() {
    var source = Fixtures.source()
    source.files["index.yaml", default: ""] += "  - core\n"
    #expect(Fixtures.errors(source).contains { $0.contains("packs/core.yaml") && $0.contains("twice") })
}

@Test func unsupportedSchemaVersionIsRejected() {
    var source = Fixtures.source()
    source.files["index.yaml"] = source.files["index.yaml"]?.replacingOccurrences(of: "schemaVersion: 1", with: "schemaVersion: 2")
    #expect(Fixtures.errors(source).contains { $0.contains("schemaVersion") })
}

@Test func mergeSourceThatIsNotAMappingIsRejected() {
    let core = Fixtures.core.replacingOccurrences(of: "    <<: *producer\n", with: "    <<: 5\n")
    let errors = Fixtures.errors(Fixtures.source([("core", core), ("ages", Fixtures.ages)]))
    #expect(errors.contains { $0.hasPrefix("packs/core.yaml") && $0.contains("<<") })
}
