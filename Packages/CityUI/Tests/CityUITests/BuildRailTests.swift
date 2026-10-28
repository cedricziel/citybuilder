import Foundation
import Testing
@testable import CityCore
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

@MainActor
@Test("scenario: locked drawer tile does nothing")
func scenarioLockedDrawerTileDoesNothing() {
    let session = GameSession()
    #expect(session.isLocked(.mine))
    var rail = BuildRailModel()
    rail.toggle(.gather)
    rail.arm(.mine, in: session)
    #expect(session.selectedTool == .inspect)
    #expect(rail.openDrawer == .gather)
}

@MainActor
@Test("scenario: locked drawer tile names its research")
func scenarioLockedDrawerTileNamesItsResearch() {
    let session = GameSession()
    #expect(session.drawerCaption(for: .mine) == "Needs Mining")
    #expect(session.drawerCaption(for: .farm) == "$\(BuildingCatalog.spec(for: .farm).cost)")
}

@MainActor
@Test("VoiceOver reads a drawer tile's caption")
func drawerTileAccessibilityReadsItsCaption() {
    let session = GameSession()
    let mine = BuildDrawerView.tileAccessibility(for: .mine, in: session)
    #expect(mine.label == "Mine, locked")
    #expect(mine.value == "Needs Mining")
    let farm = BuildDrawerView.tileAccessibility(for: .farm, in: session)
    #expect(farm.label == "Farm")
    #expect(farm.value == "$\(BuildingCatalog.spec(for: .farm).cost)")
}

@MainActor
@Test("a researched building's drawer tile shows its cost again")
func researchedDrawerTileShowsItsCost() {
    var world = World.newGame()
    world.research.markResearched(.mining)
    let session = GameSession(world: world)
    #expect(!session.isLocked(.mine))
    #expect(session.drawerCaption(for: .mine) == "$\(BuildingCatalog.spec(for: .mine).cost)")
}

@MainActor
@Test("scenario: arming clears the selection")
func scenarioArmingClearsTheSelection() {
    let session = GameSession()
    session.selectedTile = TileCoordinate(x: 4, y: 4)
    session.selectTool(.place(.road))
    #expect(session.selectedTile == nil)
}

@Test("scenario: a drawer on a short screen leaves room for the status pill")
func drawerShortensOnAShortScreen() {
    #expect(BuildDrawerView.tilesHeight(availableHeight: .infinity) == 280)
    #expect(BuildDrawerView.tilesHeight(availableHeight: 300) == 236)
    #expect(BuildDrawerView.tilesHeight(availableHeight: 100) == 96)
}
