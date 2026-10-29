/// Campaign and chapter checks (`add-campaigns` D1). Every error names
/// its chapter or campaign.
extension Validator {
    /// The card text limit, in characters.
    static let cardTextLimit = 320
    /// The smallest `pushMineOut` radius: beyond the town center's start area.
    static let minimumMineRadius = 8

    /// Every chapter belongs to exactly one campaign, every listed chapter
    /// exists, and `opensAfter` names a chapter.
    func checkCampaigns(_ chapters: [String: ChapterData]) {
        var owner: [String: String] = [:]
        for campaign in data.campaigns {
            let report = reporter("Campaign", campaign.id, campaign.origin)
            if campaign.title.isEmpty { report("`title` must not be empty") }
            if campaign.chapters.isEmpty { report("`chapters` must name at least one chapter") }
            for chapter in campaign.chapters {
                if chapters[chapter] == nil { report("`chapters` names unknown chapter `\(chapter)`") }
                if let first = owner[chapter] {
                    report("chapter `\(chapter)` is already in campaign `\(first)`")
                } else {
                    owner[chapter] = campaign.id
                }
            }
            if let after = campaign.opensAfter {
                if chapters[after] == nil { report("`opensAfter` names unknown chapter `\(after)`") }
                if chapters[after]?.comingLater == true { report("`opensAfter` names `\(after)`, which is coming later") }
            }
        }
        for chapter in data.chapters where owner[chapter.id] == nil {
            reporter("Chapter", chapter.id, chapter.origin)("no campaign lists this chapter")
        }
        checkOpeningCycles(owner: owner)
    }

    /// A campaign that opens after one of its own chapters, or after a
    /// campaign that waits on it, never opens.
    private func checkOpeningCycles(owner: [String: String]) {
        // A repeated campaign id is reported elsewhere; the first one counts here.
        let waitsOn = Dictionary(data.campaigns.map { ($0.id, $0.opensAfter.flatMap { owner[$0] }) }) { first, _ in first }
        for campaign in data.campaigns {
            var seen: Set<String> = []
            var next = waitsOn[campaign.id] ?? nil
            while let current = next, seen.insert(current).inserted {
                if current == campaign.id {
                    reporter("Campaign", campaign.id, campaign.origin)(
                        "never opens: `opensAfter` leads back to this campaign's own chapters"
                    )
                    break
                }
                next = waitsOn[current] ?? nil
            }
        }
    }

    func check(_ chapter: ChapterData, _ refs: References) {
        let report = reporter("Chapter", chapter.id, chapter.origin)
        checkSetup(chapter, refs, report)
        for (field, text) in [("intro", chapter.intro), ("ending", chapter.ending)] {
            if text.isEmpty { report("`\(field)` must not be empty") }
            if text.count > Self.cardTextLimit {
                report("`\(field)` is \(text.count) characters; the limit is \(Self.cardTextLimit)")
            }
        }
        if chapter.goals.isEmpty { report("`goals` must name at least one goal that is not a bonus goal") }
        for goal in chapter.goals + chapter.bonus {
            checkGoal(goal, refs, report)
        }
        checkLose(chapter, refs, report)
        checkEvents(chapter, refs, report)
    }

    private func checkSetup(_ chapter: ChapterData, _ refs: References, _ report: (String) -> Void) {
        if chapter.title.isEmpty { report("`title` must not be empty") }
        if !ChapterReader.layouts.contains(chapter.layout) {
            report("`layout` must be one of \(ChapterReader.layouts.sorted().joined(separator: ", ")), not `\(chapter.layout)`")
        }
        if chapter.seed < 0 { report("`seed` must not be negative") }
        if refs.ages[chapter.age] == nil { report("`age` names unknown age `\(chapter.age)`") }
        if let culture = chapter.culture, refs.cultures[culture] == nil { report("`culture` names unknown culture `\(culture)`") }
        if !(0 ... 3).contains(chapter.rivals) { report("`rivals` must be from 0 to 3: there are three rival cultures") }
        if chapter.rivals > 0, chapter.layout != "archipelago" { report("rivals need the archipelago layout") }
        if chapter.start.money < 0 { report("`money` must not be negative") }
        checkGoods(chapter.start.stock, field: "stock", refs, report)
        for (difficulty, start) in chapter.overrides.sorted(by: { $0.key < $1.key }) {
            if !ItemSchema.difficulties.contains(difficulty) { report("`overrides` names unknown difficulty `\(difficulty)`") }
            if let money = start.money, money < 0 { report("`overrides.\(difficulty).money` must not be negative") }
            checkGoods(start.stock ?? [], field: "overrides.\(difficulty).stock", refs, report)
            checkRivalAgeYears(start.rivalAgeYears ?? [:], field: "overrides.\(difficulty).rivalAgeYears", chapter, refs, report)
        }
        checkLists(chapter, refs, report)
        checkDirectives(chapter, report)
    }

    private func checkLists(_ chapter: ChapterData, _ refs: References, _ report: (String) -> Void) {
        for building in chapter.closedBuildings where refs.buildings[building] == nil {
            report("`closedBuildings` names unknown building `\(building)`")
        }
        for tech in chapter.closedTechs + chapter.researched where refs.techs[tech] == nil {
            report("names unknown tech `\(tech)`")
        }
        let atStart = Set(chapter.researched).union(grantedTechs(at: chapter.age))
        for tech in chapter.closedTechs where atStart.contains(tech) {
            report("`closedTechs` closes `\(tech)`, which is researched at the start")
        }
        for difficulty in chapter.difficulties where !ItemSchema.difficulties.contains(difficulty) {
            report("`difficulties` names unknown difficulty `\(difficulty)`")
        }
        if chapter.difficulties.isEmpty { report("`difficulties` must name at least one difficulty") }
        if let order = chapter.order, !ChapterReader.orders.contains(order) { report("`sweep.order` must be careful or naive") }
    }

    private func checkDirectives(_ chapter: ChapterData, _ report: (String) -> Void) {
        for directive in chapter.directives {
            if let island = directive.island, island != "home", (Int(island) ?? 0) < 1 {
                report("`\(directive.kind)` island must be `home` or a rank from 1, not `\(island)`")
            }
            if directive.kind == "thinForest", !(0 ... 100).contains(directive.amount ?? -1) {
                report("`thinForest.keep` must be a percent from 0 to 100")
            }
            if directive.kind == "pushMineOut", (directive.amount ?? 0) < Self.minimumMineRadius {
                report("`pushMineOut` must be a radius of at least \(Self.minimumMineRadius), clear of the start area")
            }
        }
    }

    private func checkGoal(_ goal: ChapterGoal, _ refs: References, _ report: (String) -> Void) {
        if let amount = goal.amount, amount <= 0, goal.kind != "netIncome" { report("`\(goal.kind)` must be positive") }
        if let tier = goal.tier, refs.tiers[tier] == nil { report("goal names unknown house tier `\(tier)`") }
        guard let subject = goal.subject else { return }
        let (known, noun) = switch goal.kind {
        case "age": (refs.ages[subject] != nil, "age")
        case "research": (refs.techs[subject] != nil, "tech")
        case "buildings": (refs.buildings[subject] != nil, "building")
        default: (refs.goods[subject] != nil, "good")
        }
        if !known { report("`\(goal.kind)` goal names unknown \(noun) `\(subject)`") }
    }

    private func checkLose(_ chapter: ChapterData, _ refs: References, _ report: (String) -> Void) {
        if let deadline = chapter.deadline, let age = refs.ages[chapter.age], deadline <= age.startYear {
            report("`lose.deadline` \(deadline) must come after the start year \(age.startYear)")
        }
        if let race = chapter.race {
            if (race.age == nil) == (race.residents == nil) { report("`lose.rivalRace` needs exactly one of age or residents") }
            if let age = race.age, refs.ages[age] == nil { report("`lose.rivalRace` names unknown age `\(age)`") }
            if let tier = race.tier, refs.tiers[tier] == nil { report("`lose.rivalRace` names unknown house tier `\(tier)`") }
            if chapter.rivals == 0 { report("`lose.rivalRace` needs rivals") }
        }
        if let floor = chapter.collapse, floor <= 0 { report("`lose.collapse` must be positive") }
        checkRivalAgeYears(chapter.rivalAgeYears, field: "rivalAgeYears", chapter, refs, report)
    }

    /// `rivalAgeYears` names known ages and needs rivals.
    private func checkRivalAgeYears(
        _ years: [String: Int], field: String, _ chapter: ChapterData, _ refs: References, _ report: (String) -> Void
    ) {
        if !years.isEmpty, chapter.rivals == 0 { report("`\(field)` needs rivals") }
        for age in years.keys.sorted() where refs.ages[age] == nil {
            report("`\(field)` names unknown age `\(age)`")
        }
    }

    /// The techs a game in `age` starts with, as `World.initialResearch`
    /// grants them: Scholarship, every tech of an earlier age, and every era
    /// tech up to `age`.
    private func grantedTechs(at age: String) -> Set<String> {
        let order = data.ages.map(\.id)
        guard let current = order.firstIndex(of: age) else { return [] }
        let index = { (id: String) in order.firstIndex(of: id) ?? Int.max }
        return Set(data.techs.filter { tech in
            if tech.id == "scholarship" { return true }
            if let era = tech.era { return index(era) <= current }
            return index(tech.age) < current
        }.map(\.id))
    }

    /// Scheduled events name a known event in one of its seasons, one a
    /// year (`add-event-counterplay` D9), between the start year and the
    /// deadline.
    private func checkEvents(_ chapter: ChapterData, _ refs: References, _ report: (String) -> Void) {
        var years = Set<Int>()
        let start = refs.ages[chapter.age]?.startYear ?? Int.min
        for scheduled in chapter.events {
            if scheduled.year < start || scheduled.year >= (chapter.deadline ?? Int.max) {
                report("`events` schedules \(scheduled.year), which is not between the start year and the deadline")
            }
            if !years.insert(scheduled.year).inserted { report("`events` schedules two events in \(scheduled.year)") }
            guard let event = refs.events[scheduled.event] else {
                report("`events` names unknown event `\(scheduled.event)`")
                continue
            }
            if !event.enabled {
                report("`events` schedules `\(event.id)`, which is disabled (`enabled: false`) until its mechanic ships in step 2")
            }
            if ItemSchema.hazardEffects.contains(event.effect), scheduled.season == "spring" {
                report("`events` schedules a \(event.effect) in spring: its warning would come the year before")
            } else if !event.seasons.contains(scheduled.season) {
                report("`events` schedules `\(event.id)` in \(scheduled.season), which is not one of its seasons")
            }
        }
    }
}
