import Testing
@testable import CityCore
@testable import CityUI

// Migration gate for game-data-codegen (design D8), deleted in task 3.3:
// the palette labels and build drawers generated from the packs equal
// today's hand-written tables.

@Test(arguments: BuildingKind.allCases)
func parityBuildingLabelAndCategory(kind: BuildingKind) throws {
    let generated = try #require(GameDataParity.BuildingKind(rawValue: kind.rawValue))
    #expect(generated.displayName == BuildTool.place(kind).displayName)
    #expect(generated.category == BuildCategory.of(kind)?.rawValue)
}
