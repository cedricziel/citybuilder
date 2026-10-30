import Testing
@testable import CityUI

/// Spec: `localization` / Player-visible text comes from the catalogs. One
/// label per screen keeps today's English and resolves in German.
struct StaticTextTests {
    struct Label: Sendable, CustomTestStringConvertible {
        let key: String, english: String, german: String
        var testDescription: String {
            key
        }
    }

    static let labels: [Label] = [
        Label(key: "title.continue", english: "Continue", german: "Weiterspielen"),
        Label(key: "newGame.title", english: "New Game", german: "Neues Spiel"),
        Label(key: "campaigns.title", english: "Campaigns", german: "Kampagnen"),
        Label(key: "goals.bonusHeader", english: "Bonus · one laurel each", german: "Bonus · je ein Lorbeer"),
        Label(key: "research.title", english: "Research", german: "Forschung"),
        Label(key: "standings.title", english: "Standings", german: "Rangliste"),
        Label(key: "stats.title", english: "Statistics", german: "Statistik"),
        Label(key: "routes.empty", english: "No routes yet.", german: "Noch keine Routen."),
        Label(key: "orders.title", english: "Orders", german: "Aufträge"),
        Label(key: "market.title", english: "Market", german: "Markt"),
        Label(key: "map.hintBack", english: "Back: close", german: "Zurück: schließen"),
        Label(key: "touch.longPressHint", english: "Long-press a tile to build", german: "Halte ein Feld gedrückt, um zu bauen"),
        Label(key: "mac.quit", english: "Quit Citybuilder", german: "Citybuilder beenden"),
        Label(key: "settings.credits", english: "Credits", german: "Mitwirkende")
    ]

    @Test("each screen keeps its English and has German", arguments: labels)
    func screenLabel(_ label: Label) {
        #expect(GameText.string(label.key) == label.english)
        #expect(GameText.string(label.key, in: .de) == label.german)
    }

    @Test("format keys fill their arguments in order")
    func formatOrder() {
        #expect(GameText.string("firstSteps.progress", 2, 5) == "First steps 2/5")
        #expect(GameText.string("map.a11y.cursor", 3, 7, in: .de) == "Karte, Zeiger bei 3, 7")
        #expect(GameText.string("manifest.add", "Load") == "Add Load")
        #expect(GameText.string("manifest.add", "Laden", in: .de) == "Laden hinzufügen")
    }

    @Test("a count of goods picks its plural form")
    func goodsCount() {
        #expect(GameText.string("count.good", 1) == "1 good")
        #expect(GameText.string("count.good", 3) == "3 goods")
        #expect(GameText.string("count.good", 1, in: .de) == "1 Ware")
        #expect(GameText.string("count.good", 3, in: .de) == "3 Waren")
    }

    @Test("the stocks header composes island and count")
    func stocksHeader() {
        let goods = GameText.string("count.good", 3, in: .de)
        #expect(GameText.string("hud.stocksHeader", "Nordinsel", goods, in: .de) == "Vorräte Nordinsel · 3 Waren")
    }
}
