import CityCore
import Foundation
import Testing
@testable import CityUI

// Scenarios from openspec/changes/redesign-hud-map-first/specs/platform-shells/spec.md.

@Test("scenario: kinds sort into categories")
func scenarioKindsSortIntoCategories() {
    #expect(BuildCategory.of(.house) == .town)
    #expect(BuildCategory.of(.lumberjackHut) == .gather)
    #expect(BuildCategory.of(.sawmill) == .craft)
    #expect(BuildCategory.of(.road) == nil)
}

@Test("scenario: every buildable kind has one category")
func scenarioEveryBuildableKindHasOneCategory() {
    let kinds = BuildPalette.kinds.filter { $0 != .road }
    for kind in kinds {
        #expect(BuildCategory.of(kind) != nil, "\(kind) has no category")
    }
    let listed = BuildCategory.allCases.flatMap { BuildCategory.kinds(in: $0, isHidden: { _ in false }) }
    #expect(listed.count == kinds.count)
    #expect(Set(listed) == Set(kinds))
}

@MainActor
@Test("scenario: picking a drawer tile arms and closes")
func scenarioPickingADrawerTileArmsAndCloses() {
    let session = GameSession()
    var rail = BuildRailModel()
    rail.toggle(.craft)
    #expect(rail.openDrawer == .craft)
    rail.arm(.sawmill, in: session)
    #expect(session.selectedTool == .place(.sawmill))
    #expect(rail.openDrawer == nil)
    #expect(rail.highlightedCategory(armed: session.selectedTool) == .craft)
}

@Test("scenario: rail hotkeys")
func scenarioRailHotkeys() {
    #expect(BuildCategory.town.hotkey == "1")
    #expect(BuildCategory.gather.hotkey == "2")
    #expect(BuildCategory.craft.hotkey == "3")
    #expect(BuildRailModel.roadHotkey == "r")
    #expect(BuildRailModel.demolishHotkey == "x")
}
