import Yams

public enum GameDataLoader {
    /// Reads the manifest and every pack it lists, then validates the
    /// result. Fails with every problem found, never just the first.
    public static func load(from source: PackSource) -> Result<GameData, GameDataErrors> {
        let log = DiagnosticLog()
        var data = GameData()
        for file in packFiles(source, log: log) {
            guard let text = source.read(file) else { continue }
            readPack(text, file: file, into: &data, log: log)
        }
        if log.diagnostics.isEmpty {
            Validator(data: data, log: log).validate()
        }
        return log.diagnostics.isEmpty ? .success(data) : .failure(GameDataErrors(diagnostics: log.diagnostics))
    }

    /// Pack paths in manifest order. Reports packs the manifest lists but
    /// that do not exist, and pack files the manifest does not list.
    private static func packFiles(_ source: PackSource, log: DiagnosticLog) -> [String] {
        let manifest = "index.yaml"
        guard let text = source.read(manifest) else {
            log.error("missing manifest", at: Origin(file: manifest))
            return []
        }
        guard let node = compose(text, file: manifest, log: log), let fields = Fields(node, file: manifest, log: log) else {
            return []
        }
        if let version = fields.int("schemaVersion"), version != 1 {
            fields.error("unsupported schemaVersion \(version); this generator reads 1", "schemaVersion")
        }
        let listed = (fields.strings("packs") ?? []).map { "packs/\($0).yaml" }
        fields.finish(allowed: ["schemaVersion", "packs"])

        let existing = Set(source.packFiles())
        var seen = Set<String>()
        for file in listed {
            if !seen.insert(file).inserted { fields.error("manifest lists \(file) twice", "packs") }
            if !existing.contains(file) { fields.error("manifest lists \(file), which does not exist", "packs") }
        }
        for file in existing.sorted() where !seen.contains(file) {
            log.error("pack file is not listed in the manifest (index.yaml)", at: Origin(file: file))
        }
        return listed.filter(existing.contains)
    }

    private static func compose(_ text: String, file: String, log: DiagnosticLog) -> Node? {
        do {
            guard let node = try Yams.compose(yaml: text) else {
                log.error("file is empty", at: Origin(file: file))
                return nil
            }
            return resolvingMerges(node) { source in
                log.error("`<<` must merge a mapping or a list of mappings", at: Origin(file: file, line: source.mark?.line))
            }
        } catch {
            log.error("not valid YAML: \(error)", at: Origin(file: file))
            return nil
        }
    }

    private static func readPack(_ text: String, file: String, into data: inout GameData, log: DiagnosticLog) {
        guard let node = compose(text, file: file, log: log), let pack = Fields(node, file: file, log: log) else { return }
        pack.finish(allowed: ["defaults", "items"])
        guard let items = pack.node("items") else { return }
        guard case let .sequence(sequence) = items else {
            pack.error("`items` must be a list", "items")
            return
        }
        for item in sequence {
            guard let fields = Fields(item, file: file, log: log) else { continue }
            ItemReader(fields: fields).read(into: &data)
        }
    }
}

/// Turns one item mapping into a model value, reporting every field error.
private struct ItemReader {
    let fields: Fields

    func read(into data: inout GameData) {
        guard let kind = fields.string("kind"), let id = fields.string("id") else { return }
        fields.item = "\(kind) \(id)"
        guard let schema = ItemSchema.kinds[kind] else {
            fields.error("unknown kind `\(kind)`; expected one of \(ItemSchema.kinds.keys.sorted().joined(separator: ", "))", "kind")
            return
        }
        fields.finish(allowed: schema.allowed)
        switch kind {
        case "Good": good(id).map { data.goods.append($0) }
        case "Building": building(id).map { data.buildings.append($0) }
        case "Culture": culture(id).map { data.cultures.append($0) }
        case "Tech": tech(id).map { data.techs.append($0) }
        default: age(id).map { data.ages.append($0) }
        }
    }

    private func good(_ id: String) -> Good? {
        let name = fields.string("name"), unit = fields.string("unit"), price = fields.int("basePrice")
        guard let name, let unit, let price else { return nil }
        return Good(id: id, name: name, unit: unit, basePrice: price, origin: fields.origin)
    }

    private func building(_ id: String) -> Building? {
        let footprint = fields.ints("footprint"), cost = fields.int("cost")
        if let footprint, footprint.count != 2 { fields.error("`footprint` must be [width, height]", "footprint") }
        let recipe = fields.mapping("recipe", required: false).flatMap(readRecipe)
        let placement = fields.mapping("placement", required: false).flatMap(readPlacement)
        let effect = fields.string("effect", required: false)
        if let effect, effect != "code" { fields.error("`effect` must be `code`", "effect") }
        let building = Building(
            id: id,
            name: fields.string("name", required: false),
            legacyIds: fields.strings("legacyIds", required: false) ?? [],
            footprint: Size(width: footprint?.first ?? 0, height: footprint?.last ?? 0),
            cost: cost ?? 0,
            upkeep: fields.int("upkeep", required: false) ?? 0,
            buildTicks: fields.int("buildTicks", required: false) ?? 30,
            storage: fields.int("storage", required: false),
            category: fields.string("category", required: false),
            materials: fields.amounts("materials", required: false) ?? [],
            recipe: recipe,
            unlockedBy: fields.string("unlockedBy", required: false),
            obsoletedBy: fields.string("obsoletedBy", required: false),
            culture: fields.string("culture", required: false),
            placement: placement,
            hasCodeEffect: effect == "code",
            origin: fields.origin
        )
        return footprint?.count == 2 && cost != nil ? building : nil
    }

    private func readRecipe(_ recipe: Fields) -> Recipe? {
        recipe.finish(allowed: ["inputs", "outputs", "cycleTicks"])
        let inputs = recipe.amounts("inputs", required: false), outputs = recipe.amounts("outputs", required: false)
        guard let ticks = recipe.int("cycleTicks") else { return nil }
        return Recipe(inputs: inputs ?? [], outputs: outputs ?? [], cycleTicks: ticks)
    }

    private func readPlacement(_ placement: Fields) -> Placement? {
        placement.finish(allowed: ["shore", "terrain"])
        if (placement.node("shore") == nil) == (placement.node("terrain") == nil) {
            placement.error("`placement` needs exactly one of `shore` or `terrain`")
            return nil
        }
        if let shore = placement.mapping("shore", required: false) {
            shore.finish(allowed: ["minLand", "minWater"])
            guard let land = shore.int("minLand"), let water = shore.int("minWater") else { return nil }
            return .shore(minLand: land, minWater: water)
        }
        guard let terrain = placement.mapping("terrain") else { return nil }
        terrain.finish(allowed: ["type", "minTiles"])
        guard let type = terrain.string("type"), let tiles = terrain.int("minTiles") else { return nil }
        return .terrain(type: type, minTiles: tiles)
    }

    private func culture(_ id: String) -> Culture? {
        let tiers = fields.mapping("tiers").map { tiers in
            Dictionary(uniqueKeysWithValues: tiers.keys.compactMap { key in tiers.string(key).map { (key, $0) } })
        }
        let luxury = fields.mapping("luxury").flatMap { luxury -> LuxuryChain? in
            luxury.finish(allowed: ["raw", "good", "garden", "producer"])
            let raw = luxury.string("raw"), good = luxury.string("good")
            let garden = luxury.string("garden"), producer = luxury.string("producer")
            guard let raw, let good, let garden, let producer else { return nil }
            return LuxuryChain(raw: raw, good: good, garden: garden, producer: producer)
        }
        let name = fields.string("name"), blurb = fields.string("blurb"), signature = fields.string("signature")
        let names = fields.strings("residentNames")
        guard let name, let blurb, let signature, let names, let tiers, let luxury else { return nil }
        return Culture(
            id: id, name: name, blurb: blurb, tiers: tiers, luxury: luxury,
            signature: signature, residentNames: names, origin: fields.origin
        )
    }

    private func tech(_ id: String) -> Tech? {
        let gate = fields.mapping("eraGate", required: false).flatMap { gate -> EraGate? in
            gate.finish(allowed: ["tier", "residents"])
            let tier = gate.string("tier"), residents = gate.int("residents")
            guard let tier, let residents else { return nil }
            return EraGate(tier: tier, residents: residents)
        }
        let cost = fields.int("cost"), age = fields.string("age")
        guard let cost, let age else { return nil }
        return Tech(
            id: id,
            name: fields.string("name", required: false),
            cost: cost,
            age: age,
            prerequisites: fields.strings("prerequisites", required: false) ?? [],
            era: fields.string("era", required: false),
            eraGate: gate,
            origin: fields.origin
        )
    }

    private func age(_ id: String) -> Age? {
        let year = fields.int("startYear"), blurb = fields.string("blurb")
        let signature = fields.string("signature"), rival = fields.int("rivalResidents")
        guard let year, let blurb, let signature, let rival else { return nil }
        return Age(
            id: id, name: fields.string("name", required: false), startYear: year, blurb: blurb,
            signature: signature, rivalResidents: rival, origin: fields.origin
        )
    }
}
