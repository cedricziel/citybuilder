import CityCore
import Testing
@testable import CityUI

/// Spec: `localization` / Arguments are formatted for the player's language.
/// The banners' builders resolve in English here; German is checked by key.
struct BannerTextTests {
    @Test("scenario: counts pick the plural form")
    func countsPickPluralForm() {
        #expect(GameText.string("count.building", 1) == "1 building")
        #expect(GameText.string("count.building", 3) == "3 buildings")
        #expect(GameText.string("count.building", 1, in: .de) == "1 Gebäude")
        #expect(GameText.string("count.building", 3, in: .de) == "3 Gebäude")
    }

    @Test("a fire's toll counts residents in each language")
    func residentsCount() {
        #expect(GameText.string("count.resident", 1) == "1 resident")
        #expect(GameText.string("count.resident", 4) == "4 residents")
        #expect(GameText.string("count.resident", 1, in: .de) == "1 Einwohner")
        #expect(GameText.string("count.resident", 4, in: .de) == "4 Einwohner")
    }

    @MainActor
    @Test("hint banners keep their English")
    func hintsKeepEnglish() {
        let problem = GameSession.problemHint(name: "Sawmill", problem: "No road")
        #expect(problem == SessionBanner(title: "Sawmill has a problem", description: "No road. Tap it for details."))
        #expect(GameSession.gameOverBanner.title == "Bankrupt")
    }

    @Test("order banners read naturally in German")
    func orderBannersGerman() {
        #expect(GameText.string("banner.order.offered.crown", 12, "Holz", in: .de) == "Auftrag der Krone: 12 Holz")
        #expect(GameText.string("banner.order.lapsed.title.crown", in: .de) == "Ein Angebot der Krone ist verfallen")
        #expect(GameText.string("banner.order.filled.title", 12, "Holz", in: .de) == "Auftrag erfüllt: 12 Holz")
    }

    @Test("the deficit hint names upkeep and tax in German")
    func deficitGerman() {
        #expect(GameText.string("banner.deficit.title", 300, 120, in: .de) == "Im Minus: Unterhalt $300, Steuern $120")
    }

    @Test("the idle-good list adds English articles only")
    func idleGoodListArticles() {
        #expect(GameText.string("banner.idle.user", "sawmill") == "a sawmill")
        #expect(GameText.string("banner.idle.user", "Sägewerk", in: .de) == "Sägewerk")
    }

    @Test("the event chip reads in English and German")
    func eventChip() {
        #expect(GameText.string("chip.fireBurning", 2) == "Fire · 2 burning")
        #expect(GameText.string("chip.fireBurning", 1, in: .de) == "Feuer · 1 Brand")
        #expect(GameText.string("chip.fireBurning", 2, in: .de) == "Feuer · 2 Brände")
        #expect(GameText.string("chip.festival", "Herbst", in: .de) == "Fest · bis Herbst")
    }
}
