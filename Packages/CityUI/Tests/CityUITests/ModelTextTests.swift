import CityCore
import Testing
@testable import CityUI

/// Spec: `localization` / Arguments are formatted for the player's language.
/// The view models' sentences resolve in English here; German by key.
struct ModelTextTests {
    @Test("English lowercases a name inside a sentence, German keeps it")
    func inSentence() {
        #expect(GameText.inSentence("Grain Farm", in: .en) == "grain farm")
        #expect(GameText.inSentence("Kornfeld", in: .de) == "Kornfeld")
    }

    @Test("tool hints name the platform's action in whole sentences")
    func toolHints() {
        #expect(ToolStripText.hint(for: .demolish, idiom: .phone) == "Tap a building to demolish")
        #expect(ToolStripText.hint(for: .demolish, idiom: .tv) == "Click a building to demolish")
        #expect(GameText.string("tool.demolishHint.tap", in: .de) == "Tippe auf ein Gebäude, um es abzureißen")
    }

    @Test("a perk keeps its literal percent sign")
    func perkPercent() {
        #expect(GameText.string("orders.perk.research", 10) == "research costs 10% less")
        #expect(GameText.string("orders.perk.prices", 5, in: .de) == "Preise 5 % besser")
    }

    @Test("trees in reach pick their plural form")
    func treesInReach() {
        #expect(AreaCountCapsuleModel.text(kind: .lumberjackHut, count: 1) == "1 tree in reach")
        #expect(AreaCountCapsuleModel.text(kind: .lumberjackHut, count: 0) == "No trees in reach")
        #expect(GameText.string("aoe.trees", 1, in: .de) == "1 Baum in Reichweite")
        #expect(GameText.string("aoe.trees", 4, in: .de) == "4 Bäume in Reichweite")
    }

    @Test("ships on a route count in German")
    func shipCount() {
        #expect(GameText.string("count.ship", 1) == "1 ship")
        #expect(GameText.string("count.ship", 2, in: .de) == "2 Schiffe")
    }
}
