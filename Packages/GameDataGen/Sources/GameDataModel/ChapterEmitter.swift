/// Writes `CampaignCatalog`: every campaign and chapter as a value, in
/// load order (`add-campaigns` D1).
struct ChapterEmitter {
    let data: GameData
    let access: String

    var catalog: String {
        let campaigns = data.campaigns.map(campaign)
        let chapters = data.chapters.map(chapter)
        return "\n\(access)enum CampaignCatalog {\n"
            + "    \(access)static let campaigns: [Campaign] = \(list(campaigns))\n\n"
            + "    \(access)static let chapters: [Chapter] = \(list(chapters))\n"
            + "}\n"
    }

    private func list(_ items: [String]) -> String {
        items.isEmpty ? "[]" : "[\n" + items.map { "        " + $0 + ",\n" }.joined() + "    ]"
    }

    private func campaign(_ campaign: CampaignData) -> String {
        "Campaign(id: \(literal(campaign.id)), title: \(literal(campaign.title)), "
            + "chapters: [\(campaign.chapters.map(literal).joined(separator: ", "))], "
            + "opensAfter: \(campaign.opensAfter.map(literal) ?? "nil"), "
            + "titleKey: \(literal(packKey("campaign", campaign.id, "title"))))"
    }

    private func chapter(_ chapter: ChapterData) -> String {
        let goals = chapter.goals.map { goalState($0, bonus: false) } + chapter.bonus.map { goalState($0, bonus: true) }
        let fields = [
            "id: \(literal(chapter.id))", "title: \(literal(chapter.title))",
            "intro: \(literal(chapter.intro))", "ending: \(literal(chapter.ending))",
            "layout: \(chapter.layout == "archipelago" ? ".archipelago" : ".singleIsland")", "seed: \(chapter.seed)",
            "age: .\(caseName(chapter.age))", "culture: \(optionalCase(chapter.culture))",
            "rivals: \(chapter.rivals)",
            "start: ChapterStart(money: \(chapter.start.money), stock: \(amounts(chapter.start.stock)))",
            "overrides: \(overrides(chapter.overrides))",
            "directives: [\(chapter.directives.map(directive).joined(separator: ", "))]",
            "closedBuildings: \(caseList(chapter.closedBuildings))", "closedTechs: \(caseList(chapter.closedTechs))",
            "researched: \(caseList(chapter.researched))",
            "goals: [\(goals.joined(separator: ", "))]",
            "loseConditions: [\(lose(chapter).joined(separator: ", "))]",
            "rivalAgeYears: \(years(chapter.rivalAgeYears))",
            "difficulties: \(caseList(chapter.difficulties))",
            "reward: .\(chapter.reward.kind)(\(literal(chapter.reward.name)))",
            "sweep: ChapterSweep(firstSteps: \(chapter.firstSteps), order: \(chapter.order.map(literal) ?? "nil"), "
                + "market: \(chapter.market), kits: [\(chapter.kits.map(literal).joined(separator: ", "))])",
            "comingLater: \(chapter.comingLater)",
            "events: [\(chapter.events.map(event).joined(separator: ", "))]",
            "randomEvents: \(chapter.randomEvents)",
            "textKey: \(literal("chapter.\(unquotedCaseName(chapter.id))"))"
        ]
        return "Chapter(\(fields.joined(separator: ", ")))"
    }

    private func overrides(_ overrides: [String: ChapterStartData]) -> String {
        guard !overrides.isEmpty else { return "[:]" }
        return "[" + overrides.sorted { $0.key < $1.key }.map { difficulty, start in
            ".\(difficulty): ChapterStartOverride(money: \(start.money.map(String.init) ?? "nil"), "
                + "stock: \(start.stock.map(amounts) ?? "nil"), rivalAgeYears: \(start.rivalAgeYears.map(years) ?? "nil"))"
        }.joined(separator: ", ") + "]"
    }

    private func years(_ years: [String: Int]) -> String {
        years.isEmpty ? "[:]" : "[" + years.sorted { $0.key < $1.key }.map { ".\(caseName($0.key)): \($0.value)" }
            .joined(separator: ", ") + "]"
    }

    private func island(_ island: String?) -> String {
        guard let island, island != "home" else { return ".home" }
        return ".other(rank: \(island))"
    }

    private func directive(_ directive: ChapterDirective) -> String {
        switch directive.kind {
        case "thinForest": ".thinForest(\(island(directive.island)), keepPercent: \(directive.amount ?? 0))"
        case "pushMineOut": ".pushMineOut(radius: \(directive.amount ?? 0))"
        case "noMountains": ".noMountains(\(island(directive.island)))"
        default: ".raiseMineSite(\(island(directive.island)))"
        }
    }

    /// The first tier is the default for residents; the validator
    /// rejects game data without tiers.
    private func tier(_ id: String?) -> String {
        optionalCase(id ?? data.tiers.first?.id)
    }

    private func goal(_ goal: ChapterGoal) -> String {
        let amount = goal.amount ?? 0, subject = ".\(caseName(goal.subject ?? ""))"
        return switch goal.kind {
        case "residents": ".population(\(amount), atLeast: \(tier(goal.tier)))"
        case "age": ".age(\(subject))"
        case "stock": ".stock(\(subject), \(amount))"
        case "buildings": ".buildings(\(subject), \(amount))"
        case "landed": ".landedByShip(\(subject), \(amount))"
        case "research": ".research(\(subject))"
        case "outgrowRivals": ".outgrowRivals"
        default: ".\(goal.kind)(\(amount))"
        }
    }

    private func goalState(_ goal: ChapterGoal, bonus: Bool) -> String {
        "GoalState(goal: \(self.goal(goal)), isBonus: \(bonus), holdsForSeason: \(goal.hold))"
    }

    private func lose(_ chapter: ChapterData) -> [String] {
        var conditions: [String] = []
        if let deadline = chapter.deadline { conditions.append(".deadline(year: \(deadline))") }
        if let race = chapter.race {
            let target = race.age.map { ".age(.\(caseName($0)))" }
                ?? ".population(\(race.residents ?? 0), atLeast: \(tier(race.tier)))"
            conditions.append(".rivalRace(\(target))")
        }
        if let floor = chapter.collapse { conditions.append(".collapse(below: \(floor))") }
        return conditions
    }

    private func event(_ event: ChapterEvent) -> String {
        "ScheduledSeasonalEvent(year: \(event.year), event: .\(caseName(event.event)), onset: .\(event.season))"
    }
}
