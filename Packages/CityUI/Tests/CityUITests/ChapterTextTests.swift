import Testing
@testable import CityUI

/// Spec: `localization` / Arguments are formatted for the player's language.
/// English adds articles and plural endings to names; German phrases around them.
struct ChapterTextTests {
    @Test("building goals read with English articles and plurals")
    func englishOwnGoals() {
        #expect(ChapterText.goal(.buildings(.windmill, 1), culture: nil) == "Own a windmill")
        #expect(ChapterText.goal(.buildings(.windmill, 3), culture: nil) == "Own 3 windmills")
    }

    @Test("German building goals need no article or plural ending")
    func germanOwnGoals() {
        #expect(GameText.string("goal.ownOne", "Windmühle", in: .de) == "Besitze: Windmühle")
        #expect(GameText.string("goal.ownMany", 3, "Windmühle", in: .de) == "Besitze 3 × Windmühle")
    }

    @Test("time left counts years and seasons in each language")
    func timeLeft() {
        #expect(GameText.string("count.year", 1, in: .de) == "1 Jahr")
        #expect(GameText.string("count.season", 3, in: .de) == "3 Jahreszeiten")
        #expect(GameText.string("time.left", "2 Jahre", in: .de) == "noch 2 Jahre")
    }

    @Test("years before year 1 read BC")
    func yearsBC() {
        #expect(ChapterText.year(0) == "1 BC")
        #expect(GameText.string("date.yearBC", 1, in: .de) == "1 v. Chr.")
    }

    @Test("orders goals pick their plural form")
    func ordersGoal() {
        #expect(GameText.string("goal.orders", 1) == "Fulfil an order")
        #expect(GameText.string("goal.orders", 2, in: .de) == "Erfülle 2 Aufträge")
    }
}
