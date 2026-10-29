/// Checks references across all packs and the invariants the generated
/// Swift relies on. Runs only once every pack decoded cleanly.
struct Validator {
    let data: GameData
    let log: DiagnosticLog

    func validate() {
        let refs = References(
            goods: unique(data.goods, kind: "Good", id: \.id, origin: \.origin),
            buildings: unique(data.buildings, kind: "Building", id: \.id, origin: \.origin),
            cultures: unique(data.cultures, kind: "Culture", id: \.id, origin: \.origin),
            techs: unique(data.techs, kind: "Tech", id: \.id, origin: \.origin),
            ages: unique(data.ages, kind: "Age", id: \.id, origin: \.origin),
            tiers: unique(data.tiers, kind: "Tier", id: \.id, origin: \.origin),
            events: unique(data.events, kind: "Event", id: \.id, origin: \.origin)
        )
        _ = unique(data.orders, kind: "Order", id: \.id, origin: \.origin)
        _ = unique(data.campaigns, kind: "Campaign", id: \.id, origin: \.origin)
        let chapters = unique(data.chapters, kind: "Chapter", id: \.id, origin: \.origin)
        data.goods.forEach { check($0, refs) }
        data.tiers.forEach { check($0, refs) }
        data.buildings.forEach { check($0, refs) }
        data.cultures.forEach { check($0, refs) }
        data.techs.forEach { check($0, refs) }
        data.ages.forEach { check($0, refs) }
        data.orders.forEach { check($0, refs) }
        data.events.forEach { check($0, refs) }
        checkCampaigns(chapters)
        data.chapters.forEach { check($0, refs) }
        checkLegacyIds()
        checkPrerequisiteCycles(refs.techs)
        checkConsumers()
        if data.tiers.isEmpty {
            log.error("no house tiers: declare at least one `Tier` item in a pack", at: Origin(file: "index.yaml"))
        }
    }

    struct References {
        let goods: [String: Good]
        let buildings: [String: Building]
        let cultures: [String: Culture]
        let techs: [String: Tech]
        let ages: [String: Age]
        let tiers: [String: Tier]
        let events: [String: SeasonalEvent]

        var tierList: String {
            tiers.keys.sorted().joined(separator: ", ")
        }
    }

    func reporter(_ kind: String, _ id: String, _ origin: Origin) -> (String) -> Void {
        { log.error($0, at: origin, item: "\(kind) \(id)") }
    }

    // MARK: - Identifiers

    /// Items by id. A repeated id is reported at its second declaration,
    /// naming the first.
    private func unique<T>(_ items: [T], kind: String, id: KeyPath<T, String>, origin: KeyPath<T, Origin>) -> [String: T] {
        var byID: [String: T] = [:]
        var byCaseName: [String: T] = [:]
        for item in items {
            let key = item[keyPath: id], report = reporter(kind, key, item[keyPath: origin])
            if key.wholeMatch(of: /[a-z][a-z0-9]*(-[a-z0-9]+)*/) == nil {
                report("id must be lower-case words joined by hyphens")
            }
            if let first = byID[key] {
                report("duplicate \(kind) id, first declared at \(first[keyPath: origin])")
                continue
            }
            byID[key] = item
            let name = unquotedCaseName(key)
            if let first = byCaseName[name] {
                report("id gives the Swift case `\(name)`, like `\(first[keyPath: id])` at \(first[keyPath: origin])")
            } else {
                byCaseName[name] = item
            }
        }
        return byID
    }

    private func checkLegacyIds() {
        var taken = Set(data.buildings.map(\.id))
        for building in data.buildings {
            for legacy in building.legacyIds where !taken.insert(legacy).inserted {
                reporter("Building", building.id, building.origin)("legacy id `\(legacy)` is already used")
            }
        }
    }

    // MARK: - Items

    private func check(_ good: Good, _ refs: References) {
        let report = reporter("Good", good.id, good.origin)
        if good.basePrice <= 0 { report("`basePrice` must be positive") }
        if good.market.buy < 0 || good.market.sell < 0 { report("`market` limits must not be negative") }
        var named = Set<String>()
        for tier in good.neededBy {
            guard let declared = refs.tiers[tier] else {
                report("`neededBy` names unknown house tier `\(tier)`; expected one of \(refs.tierList)")
                continue
            }
            if !named.insert(tier).inserted {
                report("`neededBy` names `\(tier)` twice")
            } else if declared.needs.contains(good.id) {
                report("`neededBy` names `\(tier)`, which already needs `\(good.id)`")
            }
        }
    }

    private func check(_ tier: Tier, _ refs: References) {
        let report = reporter("Tier", tier.id, tier.origin)
        if tier.capacity <= 0 { report("`capacity` must be positive") }
        if tier.taxPerResident < 0 { report("`taxPerResident` must not be negative") }
        // A house counts its short intervals in a UInt8 that saturates at 255, and Easy adds one.
        if !(1 ... 254).contains(tier.declineGrace) { report("`declineGrace` must be between 1 and 254; omit it for 1") }
        var seen = Set<String>()
        for good in tier.needs {
            if refs.goods[good] == nil { report("`needs` names unknown good `\(good)`") }
            if !seen.insert(good).inserted { report("`needs` lists `\(good)` twice") }
        }
    }

    private func check(_ building: Building, _ refs: References) {
        let report = reporter("Building", building.id, building.origin)
        checkNumbers(building, report)
        if let category = building.category, !ItemSchema.buildingCategories.contains(category) {
            report("unknown category `\(category)`; expected one of \(ItemSchema.buildingCategories.sorted().joined(separator: ", "))")
        }
        checkGoods(building.materials, field: "materials", refs, report)
        if let recipe = building.recipe {
            checkGoods(recipe.inputs, field: "recipe.inputs", refs, report)
            checkGoods(recipe.outputs, field: "recipe.outputs", refs, report)
        }
        if !building.hasCodeEffect, building.recipe?.outputs.isEmpty ?? true {
            report("inert building: no recipe that produces goods and no `effect: code`")
        }
        for (field, tech) in [("unlockedBy", building.unlockedBy), ("obsoletedBy", building.obsoletedBy)] {
            if let tech, refs.techs[tech] == nil { report("`\(field)` names unknown tech `\(tech)`") }
        }
        if let culture = building.culture, refs.cultures[culture] == nil {
            report("`culture` names unknown culture `\(culture)`")
        }
        if case let .terrain(type, _)? = building.placement, !ItemSchema.terrainTypes.contains(type) {
            report("unknown terrain `\(type)`; expected one of \(ItemSchema.terrainTypes.sorted().joined(separator: ", "))")
        }
        if let accepts = building.accepts {
            if building.storagePerGood == nil { report("`accepts` needs `storagePerGood`: only a store limits its goods") }
            checkGoods(accepts.map { GoodAmount(good: $0, amount: 1) }, field: "accepts", refs, report)
        }
        if building.isCrop, building.recipe?.outputs.isEmpty ?? true { report("`crop` needs a recipe that grows a good") }
    }

    private func check(_ event: SeasonalEvent, _ refs: References) {
        let report = reporter("Event", event.id, event.origin)
        if !ItemSchema.eventEffects.contains(event.effect) {
            report("`effect` must be one of \(ItemSchema.eventEffects.sorted().joined(separator: ", ")), not `\(event.effect)`")
        }
        if let age = event.minAge, refs.ages[age] == nil { report("`minAge` names unknown age `\(age)`") }
        if event.seasons.isEmpty { report("`seasons` must name at least one season") }
        for season in event.seasons where !ItemSchema.seasons.contains(season) {
            report("`seasons` names unknown season `\(season)`")
        }
        if ItemSchema.hazardEffects.contains(event.effect), event.seasons.contains("spring") {
            report("a \(event.effect) can't strike in spring: its warning would come the season before, in the previous year")
        }
        for difficulty in ItemSchema.difficulties {
            guard let weight = event.weights[difficulty] else {
                report("`weight` is missing `\(difficulty)`")
                continue
            }
            if weight < 0 { report("`weight` for \(difficulty) must not be negative") }
        }
        for banner in event.banners where banner.title.isEmpty {
            report("`banners.\(banner.key).title` must not be empty")
        }
    }

    /// A planter plants within its catchment, and a harvester's Swift behaviour cuts within it, so
    /// both need a radius.
    private func checkCatchment(_ building: Building, _ report: (String) -> Void) {
        guard let radius = building.catchmentRadius else {
            if building.plantTicks != nil { report("`plantTicks` needs a `catchmentRadius` to plant within") }
            if ItemSchema.catchmentHarvesters.contains(building.id) {
                report("`catchmentRadius` is required: its Swift behaviour harvests within it")
            }
            return
        }
        if radius <= 0 { report("`catchmentRadius` must be positive") }
    }

    private func checkNumbers(_ building: Building, _ report: (String) -> Void) {
        if building.footprint.width <= 0 || building.footprint.height <= 0 { report("`footprint` must be positive") }
        if building.cost < 0 || building.upkeep < 0 { report("`cost` and `upkeep` must not be negative") }
        if building.buildTicks <= 0 { report("`buildTicks` must be positive") }
        if let storage = building.storage, storage <= 0 { report("`storage` must be positive; omit it for none") }
        if let perGood = building.storagePerGood, perGood <= 0 { report("`storagePerGood` must be positive; omit it for none") }
        if building.storage != nil, building.storagePerGood != nil { report("set `storage` or `storagePerGood`, not both") }
        if let ticks = building.plantTicks, ticks <= 0 { report("`plantTicks` must be positive") }
        checkCatchment(building, report)
        if let ticks = building.recipe?.cycleTicks, ticks <= 0 { report("`recipe.cycleTicks` must be positive") }
        switch building.placement {
        case let .shore(land, water)? where land <= 0 || water <= 0:
            report("`placement.shore` minima must be positive")
        case let .terrain(_, tiles)? where tiles <= 0:
            report("`placement.terrain.minTiles` must be positive")
        default:
            break
        }
    }

    func checkGoods(_ amounts: GoodAmounts, field: String, _ refs: References, _ report: (String) -> Void) {
        for entry in amounts {
            if refs.goods[entry.good] == nil { report("`\(field)` names unknown good `\(entry.good)`") }
            if entry.amount <= 0 { report("`\(field).\(entry.good)` must be positive") }
        }
    }

    private func check(_ culture: Culture, _ refs: References) {
        let report = reporter("Culture", culture.id, culture.origin)
        for tier in culture.tiers.keys.sorted() where refs.tiers[tier] == nil {
            report("`tiers` names unknown house tier `\(tier)`; expected one of \(refs.tierList)")
        }
        if culture.residentNames.isEmpty { report("`residentNames` must not be empty") }
        checkOwnBuilding(culture.signature, field: "signature", of: culture, refs, report)
        checkLuxury(culture, refs, report)
    }

    private func checkLuxury(_ culture: Culture, _ refs: References, _ report: (String) -> Void) {
        let chain = culture.luxury
        for (role, good) in [("raw", chain.raw), ("good", chain.good)] where refs.goods[good] == nil {
            report("`luxury.\(role)` names unknown good `\(good)`")
        }
        checkOwnBuilding(chain.garden, field: "luxury.garden", of: culture, refs, report)
        checkOwnBuilding(chain.producer, field: "luxury.producer", of: culture, refs, report)
        if let garden = refs.buildings[chain.garden], !(garden.recipe?.outputs.contains { $0.good == chain.raw } ?? false) {
            report("`luxury.garden` building `\(chain.garden)` must produce `\(chain.raw)`")
        }
        if let producer = refs.buildings[chain.producer] {
            let usesRaw = producer.recipe?.inputs.contains { $0.good == chain.raw } ?? false
            let makesGood = producer.recipe?.outputs.contains { $0.good == chain.good } ?? false
            if !usesRaw || !makesGood {
                report("`luxury.producer` building `\(chain.producer)` must turn `\(chain.raw)` into `\(chain.good)`")
            }
        }
    }

    /// A culture's signature, garden and producer must exist and set
    /// `culture:` to that culture, so no other culture can build them.
    private func checkOwnBuilding(_ id: String, field: String, of culture: Culture, _ refs: References, _ report: (String) -> Void) {
        guard let building = refs.buildings[id] else {
            report("`\(field)` names unknown building `\(id)`")
            return
        }
        if building.culture != culture.id {
            report("`\(field)` building `\(id)` must set `culture: \(culture.id)`")
        }
    }

    private func check(_ tech: Tech, _ refs: References) {
        let report = reporter("Tech", tech.id, tech.origin)
        if tech.cost <= 0 { report("`cost` must be positive") }
        if refs.ages[tech.age] == nil { report("`age` names unknown age `\(tech.age)`") }
        if let era = tech.era, refs.ages[era] == nil { report("`era` names unknown age `\(era)`") }
        for prerequisite in tech.prerequisites where refs.techs[prerequisite] == nil {
            report("`prerequisites` names unknown tech `\(prerequisite)`")
        }
        switch (tech.era, tech.eraGate) {
        case (.some, nil): report("an era tech needs an `eraGate`")
        case (nil, .some): report("`eraGate` is only for era techs; add `era` or remove it")
        default: break
        }
        if let gate = tech.eraGate {
            if refs.tiers[gate.tier] == nil {
                report("`eraGate.tier` names unknown house tier `\(gate.tier)`; expected one of \(refs.tierList)")
            }
            if gate.residents <= 0 { report("`eraGate.residents` must be positive") }
        }
    }

    private func check(_ age: Age, _ refs: References) {
        let report = reporter("Age", age.id, age.origin)
        if refs.buildings[age.signature] == nil { report("`signature` names unknown building `\(age.signature)`") }
        if age.rivalResidents < 0 { report("`rivalResidents` must not be negative") }
        if !(1 ... 12).contains(age.orderEvery) { report("`orderEvery` must be from 1 to 12 seasons") }
    }

    private func check(_ order: OrderTemplate, _ refs: References) {
        let report = reporter("Order", order.id, order.origin)
        if !ItemSchema.orderIssuers.contains(order.issuer) {
            report("`issuer` must be one of \(ItemSchema.orderIssuers.sorted().joined(separator: ", ")), not `\(order.issuer)`")
        }
        if refs.goods[order.good] == nil { report("`good` names unknown good `\(order.good)`") }
        if let age = order.minAge, refs.ages[age] == nil { report("`minAge` names unknown age `\(age)`") }
        if order.title.isEmpty { report("`title` must not be empty") }
        if order.text.count > 100 { report("`text` is \(order.text.count) characters; the limit is 100") }
        if !(1 ... 8).contains(order.seasons) { report("`seasons` must be from 1 to 8") }
        if !(1 ... 300).contains(order.size) { report("`size` must be from 1 to 300 percent") }
        if order.min < 1 { report("`min` must be at least 1") }
        if order.min > order.max { report("`min` must not be above `max`") }
        if !(0 ... 500).contains(order.reward) { report("`reward` must be from 0 to 500 percent") }
        if order.favour < 0 || order.penalty < 0 { report("`favour` and `penalty` must not be negative") }
    }

    // MARK: - Consumers

    /// Every good must be a recipe input, a material, a culture's luxury or
    /// a tier need (design D5 of `tier-needs-data`).
    private func checkConsumers() {
        let needs = data.tiers.flatMap(\.needs) + data.goods.filter { !$0.neededBy.isEmpty }.map(\.id)
        var consumed = Set(data.cultures.map(\.luxury.good) + needs)
        for building in data.buildings {
            consumed.formUnion((building.materials + (building.recipe?.inputs ?? [])).map(\.good))
        }
        for good in data.goods where !consumed.contains(good.id) {
            reporter("Good", good.id, good.origin)(
                "no consumer: no recipe input, material, culture luxury or tier need names it; add `neededBy` to make it a need"
            )
        }
    }

    // MARK: - Cycles

    /// Reports each prerequisite cycle once, at the tech that closes it.
    private func checkPrerequisiteCycles(_ techs: [String: Tech]) {
        var done = Set<String>()
        var reported = Set<Set<String>>()

        func visit(_ id: String, path: [String]) {
            if let start = path.firstIndex(of: id) {
                let cycle = Array(path[start...])
                if reported.insert(Set(cycle)).inserted, let tech = techs[id] {
                    reporter("Tech", id, tech.origin)("tech prerequisite cycle: \((cycle + [id]).joined(separator: " → "))")
                }
                return
            }
            guard !done.contains(id), let tech = techs[id] else { return }
            for prerequisite in tech.prerequisites {
                visit(prerequisite, path: path + [id])
            }
            done.insert(id)
        }
        for tech in data.techs {
            visit(tech.id, path: [])
        }
    }
}
