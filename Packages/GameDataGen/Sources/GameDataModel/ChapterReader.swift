/// Reads `Campaign` and `Chapter` items (`add-campaigns` D1).
struct ChapterReader {
    let fields: Fields

    /// Goal kinds that name something, with the field holding how many.
    static let countedGoals: Set<String> = ["stock", "buildings", "landed"]
    /// Goal kinds that are a number alone.
    static let numberGoals: Set<String> = ["residents", "treasury", "netIncome", "tradeEarnings", "orders", "signatureProjects"]
    /// Goal kinds that name an age or a tech.
    static let namedGoals: Set<String> = ["age", "research"]
    static var goalKinds: Set<String> {
        countedGoals.union(numberGoals).union(namedGoals).union(["outgrowRivals"])
    }

    static let directiveKinds: Set<String> = ["thinForest", "pushMineOut", "noMountains", "raiseMineSite"]
    static let rewardKinds: Set<String> = ["banner", "decor", "mapPreset"]
    static let layouts: Set<String> = ["single-island", "archipelago"]
    static let orders: Set<String> = ["careful", "naive"]

    func campaign(_ id: String) -> CampaignData? {
        let title = fields.string("title"), chapters = fields.strings("chapters")
        guard let title, let chapters else { return nil }
        return CampaignData(
            id: id, title: title, chapters: chapters, opensAfter: fields.string("opensAfter", required: false),
            origin: fields.origin
        )
    }

    func chapter(_ id: String) -> ChapterData? {
        let title = fields.string("title"), intro = fields.string("intro"), ending = fields.string("ending")
        let layout = fields.string("layout"), seed = fields.int("seed"), age = fields.string("age")
        let money = fields.int("money"), stock = fields.amounts("stock", required: false)
        let goals = fields.mappings("goals").map { $0.compactMap(goal) }
        let reward = fields.mapping("reward").flatMap(readReward)
        let sweep = fields.mapping("sweep", required: false)
        sweep?.finish(allowed: ["firstSteps", "order", "market", "kits"])
        let lose = fields.mapping("lose", required: false)
        lose?.finish(allowed: ["deadline", "rivalRace", "collapse"])
        guard let title, let intro, let ending, let layout, let seed, let age, let money, let goals, let reward else { return nil }
        return ChapterData(
            id: id, title: title, intro: intro, ending: ending, layout: layout, seed: seed, age: age,
            culture: fields.string("culture", required: false), rivals: fields.int("rivals", required: false) ?? 0,
            start: ChapterStart(money: money, stock: stock ?? []),
            overrides: overrides(), directives: (fields.mappings("directives", required: false) ?? []).compactMap(directive),
            closedBuildings: fields.strings("closedBuildings", required: false) ?? [],
            closedTechs: fields.strings("closedTechs", required: false) ?? [],
            researched: fields.strings("researched", required: false) ?? [],
            goals: goals, bonus: (fields.mappings("bonus", required: false) ?? []).compactMap(goal),
            deadline: lose?.int("deadline", required: false),
            race: lose?.mapping("rivalRace", required: false).map(readRace),
            collapse: lose?.int("collapse", required: false),
            rivalAgeYears: yearsByAge(fields) ?? [:],
            difficulties: fields.strings("difficulties", required: false) ?? ItemSchema.difficulties,
            reward: reward, firstSteps: sweep?.bool("firstSteps", required: false) ?? true,
            order: sweep?.string("order", required: false), market: sweep?.bool("market", required: false) ?? true,
            kits: sweep?.strings("kits", required: false) ?? [],
            comingLater: fields.bool("comingLater", required: false) ?? false,
            events: (fields.mappings("events", required: false) ?? []).compactMap(event),
            randomEvents: fields.bool("randomEvents", required: false) ?? true,
            origin: fields.origin
        )
    }

    /// A goal mapping: exactly one goal kind, its count where it names
    /// something, a `tier` for residents and an optional `hold`.
    private func goal(_ goal: Fields) -> ChapterGoal? {
        guard let kind = goal.oneOf(Self.goalKinds, extra: ["count", "tier", "hold"], what: "a goal") else { return nil }
        let hold = goal.bool("hold", required: false) ?? false
        if kind == "outgrowRivals" {
            _ = goal.bool(kind)
            return ChapterGoal(kind: kind, hold: hold)
        }
        if Self.numberGoals.contains(kind) {
            guard let amount = goal.int(kind) else { return nil }
            return ChapterGoal(kind: kind, amount: amount, tier: goal.string("tier", required: false), hold: hold)
        }
        guard let subject = goal.string(kind) else { return nil }
        let amount = Self.countedGoals.contains(kind) ? goal.int("count") : nil
        if Self.countedGoals.contains(kind), amount == nil { return nil }
        return ChapterGoal(kind: kind, subject: subject, amount: amount, hold: hold)
    }

    private func directive(_ directive: Fields) -> ChapterDirective? {
        guard let kind = directive.oneOf(Self.directiveKinds, what: "a directive") else { return nil }
        switch kind {
        case "pushMineOut":
            return directive.int(kind).map { ChapterDirective(kind: kind, amount: $0) }
        case "thinForest":
            guard let thin = directive.mapping(kind) else { return nil }
            thin.finish(allowed: ["island", "keep"])
            let island = thin.scalar("island"), keep = thin.int("keep")
            guard let island, let keep else { return nil }
            return ChapterDirective(kind: kind, island: island, amount: keep)
        default:
            return directive.scalar(kind).map { ChapterDirective(kind: kind, island: $0) }
        }
    }

    private func readReward(_ reward: Fields) -> ChapterReward? {
        guard let kind = reward.oneOf(Self.rewardKinds, what: "`reward`") else { return nil }
        return reward.string(kind).map { ChapterReward(kind: kind, name: $0) }
    }

    private func readRace(_ race: Fields) -> ChapterRace {
        race.finish(allowed: ["age", "residents", "tier"])
        return ChapterRace(
            age: race.string("age", required: false), residents: race.int("residents", required: false),
            tier: race.string("tier", required: false)
        )
    }

    private func overrides() -> [String: ChapterStartData] {
        guard let overrides = fields.mapping("overrides", required: false) else { return [:] }
        return Dictionary(uniqueKeysWithValues: overrides.keys.compactMap { key in
            overrides.mapping(key).map { start in
                start.finish(allowed: ["money", "stock", "rivalAgeYears"])
                return (key, ChapterStartData(
                    money: start.int("money", required: false), stock: start.amounts("stock", required: false),
                    rivalAgeYears: yearsByAge(start)
                ))
            }
        })
    }

    private func yearsByAge(_ fields: Fields) -> [String: Int]? {
        guard let years = fields.mapping("rivalAgeYears", required: false) else { return nil }
        return Dictionary(uniqueKeysWithValues: years.keys.compactMap { key in years.int(key).map { (key, $0) } })
    }

    private func event(_ event: Fields) -> ChapterEvent? {
        event.finish(allowed: ["year", "season", "event"])
        let year = event.int("year"), season = event.string("season"), name = event.string("event")
        guard let year, let season, let name else { return nil }
        return ChapterEvent(year: year, season: season, event: name)
    }
}
