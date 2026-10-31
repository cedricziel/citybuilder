import CityCore
import Testing
@testable import CityUI

/// Spec: `localization` / Rival town names are translated for display only.
struct TownNameTests {
    @Test("scenario: a generated rival name shows in german")
    func generatedNameInGerman() throws {
        #expect(GameText.townName("Bay of Knives", in: .de) == "Messerbucht")
        #expect(GameText.townName("Bay of Knives") == "Bay of Knives")
        let world = World.newGame(layout: .archipelago, seed: 0xC17B)
        let rival = try #require(world.rivals.first)
        #expect(IslandNameTable.entries.contains(rival.name))
        #expect(GameText.townName(rival.name, in: .de) != rival.name || ["Linden", "Vellholm"].contains(rival.name))
        #expect(world.rivals.first?.name == rival.name)
    }

    @Test("scenario: an unknown rival name shows as stored")
    func unknownNameShowsAsStored() {
        #expect(GameText.townName("Neustadt am Rand", in: .de) == "Neustadt am Rand")
        #expect(GameText.townName("") == "")
    }

    @Test("every generated name has a catalog entry")
    func everyNameHasAKey() {
        for name in IslandNameTable.entries {
            #expect(GameText.string(GameText.townNameKey(name)) == name, "\(name)")
        }
        #expect(GameText.townNameKey("Mariner's Rest") == "rivalTown.marinersRest")
        #expect(GameText.townName("Mariner's Rest", in: .de) == "Seemannsruh")
    }
}

/// Text the earlier slices left in English, now through the catalog.
struct LeftoverTextTests {
    @Test("chapter select tallies and research ages read in German")
    func leftoversInGerman() {
        #expect(GameText.string("chapter.tally", 1, 3) == "1 of 3 won")
        #expect(GameText.string("chapter.tally", 1, 3, in: .de) == "1 von 3 gewonnen")
        #expect(GameText.string("research.unlocksAge", "Medieval") == "The Medieval age")
        #expect(GameText.string("research.unlocksAge", "Mittelalter", in: .de) == "Neues Zeitalter: Mittelalter")
        #expect(GameText.string("research.waitsForAge", "Medieval") == "Medieval age")
        #expect(GameText.string("research.waitsForAge", "Mittelalter", in: .de) == "Zeitalter Mittelalter")
    }
}
