import CityCore
import Foundation

/// The words the chapter screens and cards use. Spec: `platform-shells` /
/// Campaigns on the title screen, Chapter intro and ending cards.
public enum ChapterText {
    /// A goal as a target, for the chapter detail and the intro card.
    public static func goal(_ goal: Goal, culture: Culture?) -> String {
        switch goal {
        case let .population(count, tier):
            GameText.string(
                "goal.population",
                count,
                tier == .peasants ? GameText.string("goal.residents") : english(tierName(tier, culture))
            )
        case let .age(age): GameText.string("goal.age", age.displayName)
        case let .stock(good, count): GameText.string("goal.stock", count, goodName(good))
        case .outgrowRivals: GameText.string("goal.outgrow")
        case let .orders(count): GameText.string("goal.orders", count)
        case let .buildings(kind, count): ownGoal(kind, count: count)
        case let .signatureProjects(count): GameText.string("goal.signature", count)
        case let .research(tech): GameText.string("goal.research", tech.displayName)
        case let .treasury(amount): GameText.string("goal.treasury", money(amount))
        case let .netIncome(amount): GameText.string("goal.netIncome", money(amount))
        case let .tradeEarnings(amount): GameText.string("goal.trade", money(amount))
        case let .landedByShip(good, count): GameText.string("goal.landed", count, goodName(good))
        }
    }

    /// A goal state as a line: its target, and "for a season" when it holds.
    public static func goal(_ state: GoalState, culture: Culture?) -> String {
        goal(state.goal, culture: culture) + (state.holdsForSeason ? GameText.string("goal.forSeason") : "")
    }

    /// "Medieval, 1200, 1 rival".
    public static func start(_ chapter: Chapter) -> String {
        let rivals = chapter.rivals == 0
            ? GameText.string("chapter.noRivals")
            : GameText.string("count.rival", chapter.rivals)
        return "\(chapter.age.displayName), \(year(chapter.age.startYear)), \(rivals)"
    }

    /// "1210 begins, or bankruptcy".
    public static func lostIf(_ conditions: [LoseCondition]) -> String {
        let parts = conditions.map { condition -> String in
            switch condition {
            case let .deadline(year): GameText.string("lostIf.deadline", self.year(year))
            case let .rivalRace(target): GameText.string("lostIf.race", raceTarget(target))
            case let .collapse(floor): GameText.string("lostIf.collapse", floor)
            }
        }
        return (parts + [GameText.string("lostIf.bankruptcy")]).joined(separator: GameText.string("list.commaOr")).capitalizedFirst
    }

    public static func reward(_ reward: ChapterReward) -> String {
        switch reward {
        case let .banner(name): GameText.string("reward.banner", name)
        case let .decor(name): GameText.string("reward.decor", name)
        case let .mapPreset(name): GameText.string("reward.mapPreset", name)
        }
    }

    /// The lost card's title.
    public static func lost(_ reason: LossReason, in world: World) -> String {
        switch reason {
        case .deadline: GameText.string("lost.deadline")
        case let .rivalRace(id): GameText.string("lost.race", world.rival(id)?.name ?? GameText.string("lost.aRival"))
        case .collapse: GameText.string("lost.collapse")
        case .bankruptcy: GameText.string("lost.bankruptcy")
        }
    }

    /// A chapter row's status line.
    public static func status(of chapterID: String, _ status: ChapterStatus, campaigns: [Campaign]) -> String {
        switch status {
        case .open: GameText.string("chapter.open")
        case .comingLater: GameText.string("chapter.comingLater")
        case let .won(record):
            GameText.string("chapter.won", record.difficulty.displayName, GameText.string("count.laurel", record.laurels))
        case let .locked(key): key.map { lockKey($0, for: chapterID, campaigns: campaigns) } ?? GameText.string("chapter.locked")
        }
    }

    /// "Win chapter 2" when the key is in the same campaign, else "Win The
    /// Long Chronicle chapter 3".
    static func lockKey(_ key: String, for chapterID: String, campaigns: [Campaign]) -> String {
        guard let owner = campaigns.first(where: { $0.chapters.contains(key) }),
              let index = owner.chapters.firstIndex(of: key)
        else { return GameText.string("chapter.locked") }
        let sameCampaign = owner.chapters.contains(chapterID)
        return sameCampaign
            ? GameText.string("chapter.unlockSame", index + 1)
            : GameText.string("chapter.unlockOther", owner.title, index + 1)
    }

    /// "1 year, 2 seasons left": the whole seasons after this one before
    /// `deadline` begins.
    public static func timeLeft(until deadline: Int, from date: GameDate) -> String {
        let seasons = max(0, (deadline - date.year) * 4 - date.season.rawValue - 1)
        let years = seasons / 4, rest = seasons % 4
        let parts = [
            years > 0 ? GameText.string("count.year", years) : nil,
            rest > 0 ? GameText.string("count.season", rest) : nil
        ].compactMap(\.self)
        return parts.isEmpty ? GameText.string("time.lastSeason") : GameText.string("time.left", parts.joined(separator: ", "))
    }

    /// A year as the calendar shows it: BC at and below year 0.
    static func year(_ year: Int) -> String {
        year > 0 ? "\(year)" : GameText.string("date.yearBC", 1 - year)
    }

    /// "a mine", "an observatory".
    static func withArticle(_ noun: String) -> String {
        ("aeiou".contains(noun.first ?? "x") ? "an " : "a ") + noun
    }

    /// "bakeries", "windmills"; a noun already ending in s stays.
    static func plural(_ noun: String) -> String {
        if noun.hasSuffix("s") { return noun }
        if ["ch", "sh", "x", "z"].contains(where: noun.hasSuffix) { return noun + "es" }
        if noun.hasSuffix("y"), let before = noun.dropLast().last, !"aeiou".contains(before) {
            return noun.dropLast() + "ies"
        }
        return noun + "s"
    }

    static func raceTarget(_ target: RaceTarget) -> String {
        switch target {
        case let .age(age): GameText.string("race.age", age.displayName)
        case let .population(count, _): GameText.string("race.population", count)
        }
    }

    static func money(_ amount: Int) -> String {
        HUDViewModel.formatMoney(Int64(amount), locale: Language.current.locale)
    }

    private static func goodName(_ good: Good) -> String {
        english(GoodsCatalog.spec(for: good).displayName)
    }

    private static func ownGoal(_ kind: BuildingKind, count: Int) -> String {
        if count == 1 {
            GameText.string("goal.ownOne", english(kind.displayName, withArticle))
        } else {
            GameText.string("goal.ownMany", count, english(kind.displayName, plural))
        }
    }

    /// English adds an article or a plural ending to a name; German takes it as is.
    private static func english(_ name: String, _ form: (String) -> String = { $0 }) -> String {
        Language.current == .de ? name : form(name.lowercased())
    }

    private static func tierName(_ tier: HouseTier, _ culture: Culture?) -> String {
        culture.map { culture in culture.tierName(tier) } ?? tier.displayName
    }
}

private extension String {
    var capitalizedFirst: String {
        prefix(1).uppercased() + dropFirst()
    }
}
