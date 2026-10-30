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
            data.mergeNeededBy()
        }
        return log.diagnostics.isEmpty ? .success(data) : .failure(GameDataErrors(diagnostics: log.diagnostics))
    }

    /// Every item's mapping in load order, with merges resolved and before
    /// any type checks or validation. Fails only when a file can't be read
    /// as YAML or the manifest and pack files disagree.
    static func items(from source: PackSource) -> Result<[RawItem], GameDataErrors> {
        let log = DiagnosticLog()
        var items: [RawItem] = []
        for file in packFiles(source, log: log) {
            guard let text = source.read(file),
                  let node = compose(text, file: file, log: log),
                  case let .sequence(sequence)? = node.mapping?["items"]
            else { continue }
            for case let .mapping(item) in sequence {
                guard let kind = item["kind"]?.string, let id = item["id"]?.string else { continue }
                items.append(RawItem(key: "\(kind) \(id)", node: .mapping(item)))
            }
        }
        return log.diagnostics.isEmpty ? .success(items) : .failure(GameDataErrors(diagnostics: log.diagnostics))
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
        case "Tier": tier(id).map { data.tiers.append($0) }
        case "Age": age(id).map { data.ages.append($0) }
        default: read(feature: kind, id: id, into: &data)
        }
    }

    /// The kinds a feature pack adds beside the core catalog.
    private func read(feature kind: String, id: String, into data: inout GameData) {
        switch kind {
        case "Logistics": logistics(id).map { data.logistics.append($0) }
        case "Vehicle": vehicle(id).map { data.vehicles.append($0) }
        case "Order": order(id).map { data.orders.append($0) }
        case "Event": event(id).map { data.events.append($0) }
        case "Campaign": ChapterReader(fields: fields).campaign(id).map { data.campaigns.append($0) }
        default: ChapterReader(fields: fields).chapter(id).map { data.chapters.append($0) }
        }
    }

    private func good(_ id: String) -> Good? {
        let name = fields.string("name"), unit = fields.string("unit"), price = fields.int("basePrice")
        let market = fields.mapping("market", required: false).map { market in
            market.finish(allowed: ["buy", "sell"])
            return MarketLimits(buy: market.int("buy", required: false) ?? 0, sell: market.int("sell", required: false) ?? 0)
        }
        guard let name, let unit, let price else { return nil }
        return Good(
            id: id, name: name, unit: unit, basePrice: price,
            market: market ?? MarketLimits(), neededBy: fields.strings("neededBy", required: false) ?? [],
            origin: fields.origin
        )
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
            storagePerGood: fields.int("storagePerGood", required: false),
            accepts: fields.strings("accepts", required: false),
            plantTicks: fields.int("plantTicks", required: false),
            catchmentRadius: fields.int("catchmentRadius", required: false),
            category: fields.string("category", required: false),
            materials: fields.amounts("materials", required: false) ?? [],
            recipe: recipe,
            unlockedBy: fields.string("unlockedBy", required: false),
            obsoletedBy: fields.string("obsoletedBy", required: false),
            culture: fields.string("culture", required: false),
            placement: placement,
            hasCodeEffect: effect == "code",
            isCrop: fields.bool("crop", required: false) ?? false,
            fuel: fields.mapping("fuel", required: false).flatMap(readFuel),
            hub: fields.mapping("hub", required: false).flatMap(readHub),
            origin: fields.origin
        )
        return footprint?.count == 2 && cost != nil ? building : nil
    }

    private func readHub(_ hub: Fields) -> Hub? {
        hub.finish(allowed: ["radius", "housesPerPorter", "maxPorters", "basketUnits", "reserveConsumptions"])
        let radius = hub.int("radius"), perPorter = hub.int("housesPerPorter"), maxPorters = hub.int("maxPorters")
        let basket = hub.int("basketUnits"), reserve = hub.int("reserveConsumptions")
        guard let radius, let perPorter, let maxPorters, let basket, let reserve else { return nil }
        return Hub(
            radius: radius, housesPerPorter: perPorter, maxPorters: maxPorters, basketUnits: basket, reserveConsumptions: reserve
        )
    }

    private func readRecipe(_ recipe: Fields) -> Recipe? {
        recipe.finish(allowed: ["inputs", "outputs", "cycleTicks"])
        let inputs = recipe.amounts("inputs", required: false), outputs = recipe.amounts("outputs", required: false)
        guard let ticks = recipe.int("cycleTicks") else { return nil }
        return Recipe(inputs: inputs ?? [], outputs: outputs ?? [], cycleTicks: ticks)
    }

    private func readFuel(_ fuel: Fields) -> Fuel? {
        fuel.finish(allowed: ["good", "amount", "everyTicks"])
        let good = fuel.string("good"), amount = fuel.int("amount"), every = fuel.int("everyTicks")
        guard let good, let amount, let every else { return nil }
        return Fuel(good: good, amount: amount, everyTicks: every)
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
        let tiers = fields.mapping("tiers", required: false).map { tiers in
            Dictionary(uniqueKeysWithValues: tiers.keys.compactMap { key in tiers.string(key).map { (key, $0) } })
        } ?? [:]
        let luxury = fields.mapping("luxury").flatMap { luxury -> LuxuryChain? in
            luxury.finish(allowed: ["raw", "good", "garden", "producer"])
            let raw = luxury.string("raw"), good = luxury.string("good")
            let garden = luxury.string("garden"), producer = luxury.string("producer")
            guard let raw, let good, let garden, let producer else { return nil }
            return LuxuryChain(raw: raw, good: good, garden: garden, producer: producer)
        }
        let name = fields.string("name"), blurb = fields.string("blurb"), signature = fields.string("signature")
        let names = fields.strings("residentNames")
        guard let name, let blurb, let signature, let names, let luxury else { return nil }
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

    private func tier(_ id: String) -> Tier? {
        let name = fields.string("name"), capacity = fields.int("capacity")
        let tax = fields.int("taxPerResident"), needs = fields.strings("needs")
        let grace = fields.int("declineGrace", required: false)
        guard let name, let capacity, let tax, let needs else { return nil }
        return Tier(
            id: id, name: name, capacity: capacity, taxPerResident: tax, needs: needs,
            declineGrace: grace ?? 1, origin: fields.origin
        )
    }

    private func logistics(_ id: String) -> Logistics? {
        let distance = fields.int("haulDistance"), minLoad = fields.int("haulMinLoad"), maxWait = fields.int("haulMaxWait")
        let stock = fields.int("houseStockConsumptions"), minimum = fields.int("houseStockMinimum")
        guard let distance, let minLoad, let maxWait, let stock, let minimum else { return nil }
        return Logistics(
            id: id, haulDistance: distance, haulMinLoad: minLoad, haulMaxWait: maxWait,
            houseStockConsumptions: stock, houseStockMinimum: minimum, origin: fields.origin
        )
    }

    private func vehicle(_ id: String) -> Vehicle? {
        let age = fields.string("age"), capacity = fields.int("capacity")
        guard let age, let capacity else { return nil }
        return Vehicle(id: id, age: age, capacity: capacity, origin: fields.origin)
    }

    private func age(_ id: String) -> Age? {
        let year = fields.int("startYear"), blurb = fields.string("blurb")
        let signature = fields.string("signature"), rival = fields.int("rivalResidents")
        guard let year, let blurb, let signature, let rival else { return nil }
        return Age(
            id: id, name: fields.string("name", required: false), startYear: year, blurb: blurb,
            signature: signature, rivalResidents: rival, orderEvery: fields.int("orderEvery", required: false) ?? 4,
            origin: fields.origin
        )
    }

    private func order(_ id: String) -> OrderTemplate? {
        let issuer = fields.string("issuer"), good = fields.string("good")
        let title = fields.string("title"), text = fields.string("text")
        let seasons = fields.int("seasons"), size = fields.int("size")
        let min = fields.int("min"), max = fields.int("max"), reward = fields.int("reward")
        guard let issuer, let good, let title, let text, let seasons, let size, let min, let max, let reward else { return nil }
        return OrderTemplate(
            id: id, issuer: issuer, good: good, title: title, text: text,
            minAge: fields.string("minAge", required: false), seasons: seasons, size: size, min: min, max: max, reward: reward,
            favour: fields.int("favour", required: false) ?? 2, penalty: fields.int("penalty", required: false) ?? 2,
            origin: fields.origin
        )
    }

    private func event(_ id: String) -> SeasonalEvent? {
        let effect = fields.string("effect"), seasons = fields.strings("seasons")
        let weight = fields.mapping("weight").map { weight in
            weight.finish(allowed: Set(ItemSchema.difficulties))
            return Dictionary(uniqueKeysWithValues: weight.keys.compactMap { key in weight.int(key).map { (key, $0) } })
        }
        let banners = fields.mapping("banners").map { banners in
            banners.finish(allowed: Set(ItemSchema.eventBanners))
            return banners.keys.compactMap { key -> SeasonalEvent.Banner? in
                guard let banner = banners.mapping(key) else { return nil }
                banner.finish(allowed: ["title", "text"])
                let title = banner.string("title"), text = banner.string("text")
                guard let title, let text else { return nil }
                return SeasonalEvent.Banner(key: key, title: title, text: text)
            }
        }
        guard let effect, let seasons, let weight, let banners else { return nil }
        return SeasonalEvent(
            id: id, effect: effect, seasons: seasons, minAge: fields.string("minAge", required: false),
            weights: weight, banners: banners, enabled: fields.bool("enabled", required: false) ?? true,
            firstYear: fields.int("firstYear", required: false) ?? 1,
            minFoodSeasons: fields.int("minFoodSeasons", required: false) ?? 0, origin: fields.origin
        )
    }
}
