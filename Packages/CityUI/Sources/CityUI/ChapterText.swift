import CityCore
import Foundation

/// The words the chapter screens and cards use. Spec: `platform-shells` /
/// Campaigns on the title screen, Chapter intro and ending cards.
public enum ChapterText {
    /// A goal as a target, for the chapter detail and the intro card.
    public static func goal(_ goal: Goal, culture: Culture?) -> String {
        switch goal {
        case let .population(count, tier):
            "\(count) \(tier == .peasants ? "residents" : tierName(tier, culture).lowercased())"
        case let .age(age): "Reach the \(age.displayName) age"
        case let .stock(good, count): "\(count) \(goodName(good)) in store"
        case .outgrowRivals: "Outgrow every rival"
        case let .orders(count): count == 1 ? "Fulfil an order" : "Fulfil \(count) orders"
        case let .buildings(kind, count):
            count == 1 ? "Own \(withArticle(kind.displayName.lowercased()))" : "Own \(count) \(plural(kind.displayName.lowercased()))"
        case let .signatureProjects(count):
            count == 1 ? "Complete a signature project" : "Complete \(count) signature projects"
        case let .research(tech): "Research \(tech.displayName)"
        case let .treasury(amount): "Treasury of \(money(amount))"
        case let .netIncome(amount): "Net income of \(money(amount)) a season"
        case let .tradeEarnings(amount): "Earn \(money(amount)) from trade"
        case let .landedByShip(good, count): "Land \(count) \(goodName(good)) at home by ship"
        }
    }

    /// A goal state as a line: its target, and "for a season" when it holds.
    public static func goal(_ state: GoalState, culture: Culture?) -> String {
        goal(state.goal, culture: culture) + (state.holdsForSeason ? " for a season" : "")
    }

    /// "Medieval, 1200, 1 rival".
    public static func start(_ chapter: Chapter) -> String {
        let rivals = switch chapter.rivals {
        case 0: "no rivals"
        case 1: "1 rival"
        default: "\(chapter.rivals) rivals"
        }
        return "\(chapter.age.displayName), \(year(chapter.age.startYear)), \(rivals)"
    }

    /// "1210 begins, or bankruptcy".
    public static func lostIf(_ conditions: [LoseCondition]) -> String {
        let parts = conditions.map { condition -> String in
            switch condition {
            case let .deadline(year): "\(self.year(year)) begins"
            case let .rivalRace(target): "a rival reaches \(raceTarget(target)) first"
            case let .collapse(floor): "the town falls below \(floor) residents for a season"
            }
        }
        return (parts + ["bankruptcy"]).joined(separator: ", or ").capitalizedFirst
    }

    public static func reward(_ reward: ChapterReward) -> String {
        switch reward {
        case let .banner(name): "Banner “\(name)”"
        case let .decor(name): "Decor “\(name)”"
        case let .mapPreset(name): "Map preset “\(name)”"
        }
    }

    /// The lost card's title.
    public static func lost(_ reason: LossReason, in world: World) -> String {
        switch reason {
        case .deadline: "The year turned before the goals were met"
        case let .rivalRace(id): "\(world.rival(id)?.name ?? "A rival") got there first"
        case .collapse: "The town emptied out"
        case .bankruptcy: "The treasury ran dry"
        }
    }

    /// A chapter row's status line.
    public static func status(of chapterID: String, _ status: ChapterStatus, campaigns: [Campaign]) -> String {
        switch status {
        case .open: "Open"
        case .comingLater: "Coming later"
        case let .won(record):
            "Won on \(GameText.string(record.difficulty.nameKey)) · \(record.laurels) \(record.laurels == 1 ? "laurel" : "laurels")"
        case let .locked(key): key.map { lockKey($0, for: chapterID, campaigns: campaigns) } ?? "Locked"
        }
    }

    /// "Win chapter 2" when the key is in the same campaign, else "Win The
    /// Long Chronicle chapter 3".
    static func lockKey(_ key: String, for chapterID: String, campaigns: [Campaign]) -> String {
        guard let owner = campaigns.first(where: { $0.chapters.contains(key) }),
              let index = owner.chapters.firstIndex(of: key)
        else { return "Locked" }
        let sameCampaign = owner.chapters.contains(chapterID)
        return sameCampaign ? "Win chapter \(index + 1)" : "Win \(owner.title) chapter \(index + 1)"
    }

    /// "1 year, 2 seasons left": the whole seasons after this one before
    /// `deadline` begins.
    public static func timeLeft(until deadline: Int, from date: GameDate) -> String {
        let seasons = max(0, (deadline - date.year) * 4 - date.season.rawValue - 1)
        let years = seasons / 4, rest = seasons % 4
        let parts = [
            years > 0 ? "\(years) \(years == 1 ? "year" : "years")" : nil,
            rest > 0 ? "\(rest) \(rest == 1 ? "season" : "seasons")" : nil
        ].compactMap(\.self)
        return parts.isEmpty ? "Last season" : parts.joined(separator: ", ") + " left"
    }

    /// A year as the calendar shows it: BC at and below year 0.
    static func year(_ year: Int) -> String {
        year > 0 ? "\(year)" : "\(1 - year) BC"
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
        case let .age(age): "the \(age.displayName)"
        case let .population(count, _): "\(count) residents"
        }
    }

    static func money(_ amount: Int) -> String {
        HUDViewModel.formatMoney(Int64(amount), locale: .current)
    }

    private static func goodName(_ good: Good) -> String {
        GoodsCatalog.spec(for: good).displayName.lowercased()
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
