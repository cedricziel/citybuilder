import CityCore
import Testing
@testable import CityUI

/// Spec: `localization` / The simulation core emits keys and arguments, not
/// sentences; CityUI turns them into text.
struct CoreMessageTextTests {
    @Test("scenario: english keeps today's text")
    func englishKeepsTodaysText() {
        let event = HistoryEvent.bountifulHarvest
        #expect(GameText.string(event.titleKey) == "Bountiful harvest")
        #expect(GameText.string(event.message) == "The fields gave more than expected: 8 food reaches the stores.")
    }

    @Test("history events read as before in English and fill German")
    func historyEvents() {
        #expect(GameText.string(HistoryEvent.tradeCaravan.message) == "A caravan passes through and pays well: +$150.")
        #expect(GameText.string(HistoryEvent.travellingScholar.message)
            == "A visiting scholar shares what they know: +20 knowledge.")
        #expect(GameText.string(HistoryEvent.ratsInTheGranary.message) == "Rats got into the stores: half the food is lost.")
        #expect(GameText.string(HistoryEvent.tradeCaravan.message, in: .de) == "Eine Karawane zieht durch und zahlt gut: +$150.")
        #expect(GameText.string(HistoryEvent.bountifulHarvest.message, in: .de).contains("8 Nahrung"))
    }

    @Test("money in a message groups digits per language")
    func moneyGrouping() {
        let message = GameMessage("history.tradeCaravan.text", ["payment": .money(1500)])
        #expect(GameText.string(message) == "A caravan passes through and pays well: +$1,500.")
        #expect(GameText.string(message, in: .de) == "Eine Karawane zieht durch und zahlt gut: +$1.500.")
    }

    @Test("scenario: a date before year 1 reads per locale")
    func dateBeforeYearOne() {
        let date = GameDate(year: 0, season: .spring)
        #expect(GameText.date(date) == "Spring 1 BC")
        #expect(GameText.date(date, in: .de) == "Frühling 1 v. Chr.")
    }

    @Test("scenario: years before christ")
    func yearsBeforeChrist() {
        #expect(GameText.date(GameDate(year: -499, season: .spring)) == "Spring 500 BC")
        #expect(GameText.date(GameDate(year: 1, season: .summer)) == "Summer 1")
        #expect(GameText.date(GameDate(year: 1203, season: .autumn), in: .de) == "Herbst 1203")
    }

    @Test("names of seasons, difficulties and scenarios read as before")
    func enumNames() {
        #expect(Season.allCases.map { GameText.string($0.nameKey) } == ["Spring", "Summer", "Autumn", "Winter"])
        #expect(Difficulty.allCases.map { GameText.string($0.nameKey) } == ["Easy", "Normal", "Hard"])
        #expect(Difficulty.allCases.map { GameText.string($0.nameKey, in: .de) } == ["Leicht", "Normal", "Schwer"])
        #expect(Scenario.allCases.map { GameText.string($0.titleKey) }
            == ["First Harvest", "The Guild Town", "Steam and Smoke", "Island Rivalry"])
        #expect(GameText.string(Scenario.islandRivalry.blurbKey) == "Out-build two rival towns and reach 80 residents.")
    }

    /// The core builds these keys at runtime, so `l10n-check` can't see
    /// their lookups; it does check that every catalog key has German.
    @Test("every key the core names is in the catalog")
    func everyCoreKeyResolves() {
        let keys = Season.allCases.map(\.nameKey) + Difficulty.allCases.map(\.nameKey)
            + Scenario.allCases.flatMap { [$0.titleKey, $0.blurbKey] }
            + HistoryEvent.allCases.flatMap { [$0.titleKey, $0.message.key] }
        for key in keys {
            #expect(GameText.string(key) != key, "\(key)")
        }
    }
}
