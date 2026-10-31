import CityCore
import Testing
@testable import CityUI

/// Spec: `localization` / Pack text has keys generated from the YAML;
/// Arguments are formatted for the player's language. The pack text comes
/// from `GameData.xcstrings`, which GameDataGen writes.
@MainActor
struct PackTextTests {
    @Test("scenario: pack placeholders are named")
    func packPlaceholdersAreNamed() throws {
        let key = try #require(SeasonalEvent.fire.banners[.ignition]).textKey
        #expect(GameText.string(key).hasPrefix("A {building} is burning."))
        #expect(GameText.string(key, in: .de).contains("{building}"))
        let banner = try #require(GameSession.banner(.fire, .ignition, ["building": "sawmill"]))
        #expect(banner.description.hasPrefix("A sawmill is burning."))
    }

    @Test("scenario: a noun placeholder is filled with the localized noun")
    func nounPlaceholderIsLocalized() throws {
        let farm = GameText.inSentence(GameText.string(BuildingKind.grainFarm.nameKey, in: .de), in: .de)
        let banner = try #require(GameSession.banner(.fire, .ignition, ["building": farm], in: .de))
        #expect(banner.description.contains("Getreidehof"))
        for english in ["Grain", "Farm", "grain", "farm", "burning", "Fire"] {
            #expect(!banner.title.contains(english) && !banner.description.contains(english), "\(english)")
        }
    }

    @Test("pack names read as the packs write them, and in German")
    func packNames() {
        #expect(BuildingKind.grainFarm.displayName == "Grain Farm")
        #expect(BuildingKind.townCenter.displayName == "Town Ctr.")
        #expect(Good.wood.displayName == "Wood")
        #expect(Good.wood.stackUnit == "logs")
        #expect(Tech.printingPress.displayName == "Printing Press")
        #expect(Age.industrial.displayName == "Industrial")
        #expect(Culture.eastAsian.displayName == "East Asian")
        #expect(OrderTemplate.crownWood.title == "Wood for the winter")
        #expect(GameText.string(BuildingKind.townCenter.nameKey, in: .de) == "Rathaus")
        #expect(GameText.string(Good.food.nameKey, in: .de) == "Nahrung")
        #expect(GameText.string(Age.industrial.nameKey, in: .de) == "Industriezeitalter")
    }

    @Test("the fire warning names its season")
    func fireWarning() throws {
        let key = try #require(SeasonalEvent.fire.banners[.warning]).titleKey
        #expect(GameText.string(key) == "Dry {season} ahead")
    }

    @Test("order texts stay short in both languages")
    func orderTextsAreShort() {
        for template in OrderTemplate.allCases {
            for language in [Language.en, .de] {
                #expect(GameText.string(template.textKey, in: language).count <= 100, "\(template) \(language)")
            }
        }
    }

    @Test("scenario: mediterranean top tier")
    func mediterraneanTopTier() {
        #expect(HouseTier.merchants.displayName(in: .mediterranean) == "Patricians")
        #expect(GameText.string(HouseTier.merchants.nameKey(in: .mediterranean), in: .de) == "Patrizier")
    }

    @Test("scenario: northern european names are unchanged")
    func northernEuropeanNames() {
        #expect(HouseTier.allCases.map { $0.displayName(in: .northernEuropean) } == ["Peasants", "Citizens", "Merchants"])
    }

    @Test("every culture names its tiers")
    func tierNames() {
        let names: [Culture: [String]] = [
            .northernEuropean: ["Peasants", "Citizens", "Merchants"],
            .mediterranean: ["Plebeians", "Citizens", "Patricians"],
            .eastAsian: ["Farmers", "Artisans", "Scholars"],
            .middleEastern: ["Farmers", "Craftsmen", "Merchants"]
        ]
        #expect(Set(names.keys) == Set(Culture.allCases))
        for (culture, expected) in names {
            #expect(HouseTier.allCases.map { $0.displayName(in: culture) } == expected, "\(culture)")
        }
        #expect(HouseTier.allCases.map(\.displayName) == ["Peasants", "Citizens", "Merchants"])
    }

    @Test("a campaign built in code shows its stored title; a pack campaign its catalog title")
    func campaignTitle() {
        #expect(Campaign(id: "test", title: "A Test Campaign", chapters: []).displayTitle == "A Test Campaign")
        #expect(Campaign(id: "wood", title: "Stored", chapters: [], titleKey: Good.wood.nameKey).displayTitle == "Wood")
        #expect(ChapterReward.decor("Founder's stone").name == "Founder's stone")
        #expect(ChapterReward.mapPreset("Two Shores").name == "Two Shores")
    }

    /// No chapter ships yet, so a history event's keys stand in for the
    /// generated `chapter.<id>` ones; the event has no `.intro`.
    @Test("a pack chapter reads its text from the catalog; a chapter built in code shows its own")
    func chapterText() {
        func chapter(textKey: String?) -> Chapter {
            Chapter(
                id: "c", title: "Stored", intro: "Intro", ending: "End", layout: .singleIsland, seed: 1, age: .medieval,
                start: ChapterStart(money: 1000, stock: [:]), goals: [], reward: .banner("Hearth"), textKey: textKey
            )
        }
        let stored = chapter(textKey: nil)
        #expect([stored.displayTitle, stored.displayIntro, stored.displayEnding, stored.rewardName] == ["Stored", "Intro", "End", "Hearth"])
        let pack = chapter(textKey: "history.bountifulHarvest")
        #expect(pack.displayTitle == "Bountiful harvest")
        #expect(pack.displayIntro == "Intro")
        #expect(Campaign(id: "x", title: "Stored", chapters: [], titleKey: "campaign.gone.title").displayTitle == "Stored")
    }
}
