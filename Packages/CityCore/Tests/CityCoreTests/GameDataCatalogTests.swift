import Foundation
import Testing
@testable import CityCore

// Scenarios from openspec/changes/game-data-codegen (game-data-catalog).

@Test("scenario: legacy building identifiers still decode")
func scenarioLegacyBuildingIdentifiersStillDecode() throws {
    let decoder = JSONDecoder()
    #expect(try decoder.decode(BuildingKind.self, from: Data(#""lumberjack_hut""#.utf8)) == .lumberjackHut)
    #expect(try decoder.decode(BuildingKind.self, from: Data(#""town_center""#.utf8)) == .townCenter)
    #expect(try JSONEncoder().encode(BuildingKind.lumberjackHut) == Data(#""lumberjack-hut""#.utf8))
    #expect(throws: DecodingError.self) { try decoder.decode(BuildingKind.self, from: Data(#""castle""#.utf8)) }
}

@Test func everyContentCaseHasItsDisplayValues() {
    for kind in BuildingKind.allCases {
        #expect(kind.nameKey.hasPrefix("building."), "\(kind)")
        #expect((kind.category == nil) == [.road, .townCenter, .ruins].contains(kind), "\(kind)")
    }
    for culture in Culture.allCases {
        #expect(culture.nameKey.hasPrefix("culture.") && culture.blurbKey.hasPrefix("culture."), "\(culture)")
    }
    for tech in Tech.allCases {
        #expect(tech.nameKey.hasPrefix("tech."), "\(tech)")
    }
    for good in Good.allCases {
        #expect(good.nameKey == "good.\(good).name" && good.unitKey == "good.\(good).unit", "\(good)")
    }
    for culture in Culture.allCases {
        for tier in HouseTier.allCases {
            #expect([tier.nameKey, "culture.\(culture).tierName.\(tier)"].contains(tier.nameKey(in: culture)))
        }
    }
    for event in SeasonalEvent.allCases {
        for banner in event.banners.values {
            #expect(banner.titleKey.hasPrefix("seasonalEvent.\(event).banner.") && banner.textKey.hasSuffix(".text"))
        }
    }
    for age in Age.allCases {
        #expect(age.nameKey.hasPrefix("age.") && age.blurbKey.hasPrefix("age."), "\(age)")
    }
    #expect(BuildingKind.signatures == [.monument, .guildHall, .gallery, .steamEngine, .powerPlant])
}
