import Foundation
import Testing
@testable import CityCore
@testable import CityUI

// Scenarios from openspec/changes/add-touch-first-placement/specs/rendering-2_5d
// (Tile context menu on long-press).

private func tile(_ x: Int, _ y: Int) -> TileCoordinate {
    TileCoordinate(x: x, y: y)
}

@MainActor
private func grassSession(money: Int64? = nil) -> GameSession {
    let session = GameSession(world: World.fixtureWithTerrain(width: 12, height: 12, fill: .grass, seed: 1))
    if let money { session.world.economy.balance = money }
    return session
}

private func buildEntry(_ kind: BuildingKind, in items: [TileMenuItem]) -> (enabled: Bool, reason: String?)? {
    for case let .build(entryKind, enabled, reason) in items where entryKind == kind {
        return (enabled, reason)
    }
    return nil
}

private func buildKinds(in items: [TileMenuItem]) -> [BuildingKind] {
    items.compactMap { item in
        if case let .build(kind, _, _) = item { return kind }
        return nil
    }
}

@Test("scenario: menu lists every placeable building kind as a separate entry")
@MainActor
func scenarioMenuListsEveryPlaceableBuildingKindAsASeparateEntry() {
    let session = grassSession()
    let items = session.tileMenuViewModel(for: tile(3, 4)).items
    let kinds = buildKinds(in: items)
    #expect(kinds == BuildPalette.visibleKinds(isHidden: session.isObsolete))
    #expect(kinds.contains(.road))
    #expect(Set(kinds).count == kinds.count)
}

@Test("scenario: road menu entry arms the place tool without entering pending state")
@MainActor
func scenarioRoadMenuEntryArmsThePlaceToolWithoutEnteringPendingState() {
    let session = grassSession()
    session.applyMenuChoice(.build(.road), at: tile(3, 4))
    #expect(session.selectedTool == .place(.road))
    #expect(session.pendingPlacement == nil)
}

@Test("scenario: unaffordable buildings appear disabled in the menu")
@MainActor
func scenarioUnaffordableBuildingsAppearDisabledInTheMenu() {
    let session = grassSession(money: 0)
    let items = session.tileMenuViewModel(for: tile(3, 4)).items
    let sawmill = buildEntry(.sawmill, in: items)
    #expect(sawmill?.enabled == false)
    #expect(sawmill?.reason?.isEmpty == false)
    let affordable = grassSession()
    #expect(buildEntry(.sawmill, in: affordable.tileMenuViewModel(for: tile(3, 4)).items)?.enabled == true)
}

@Test("entries the world would reject on this tile appear disabled with the reason")
@MainActor
func entriesTheWorldWouldRejectOnThisTileAppearDisabledWithTheReason() {
    let session = grassSession()
    session.world.enqueue(.place(.road, at: tile(3, 4)))
    session.step()
    let house = buildEntry(.house, in: session.tileMenuViewModel(for: tile(3, 4)).items)
    #expect(house?.enabled == false)
    #expect(house?.reason == "Tile occupied")
}

@Test("scenario: locked buildings appear disabled with the research reason")
@MainActor
func scenarioLockedBuildingsAppearDisabledWithTheResearchReason() throws {
    let session = GameSession(world: World.newGame())
    let items = session.tileMenuViewModel(for: tile(3, 4)).items
    let mine = try #require(buildEntry(.mine, in: items))
    #expect(!mine.enabled)
    #expect(mine.reason == "Needs \(Tech.mining.displayName) research")
}

@Test("scenario: obsolete buildings are left out of the menu")
@MainActor
func scenarioObsoleteBuildingsAreLeftOutOfTheMenu() {
    var world = World.newGame()
    world.research.markResearched(.milling)
    let session = GameSession(world: world)
    #expect(!buildKinds(in: session.tileMenuViewModel(for: tile(3, 4)).items).contains(.quernHouse))
    let antiquity = GameSession(world: World.newGame(layout: .singleIsland, seed: 0, age: .antiquity))
    #expect(buildKinds(in: antiquity.tileMenuViewModel(for: tile(3, 4)).items).contains(.quernHouse))
}

@Test("scenario: demolish entry appears only when tile holds a player-owned building")
@MainActor
func scenarioDemolishEntryAppearsOnlyWhenTileHoldsAPlayerOwnedBuilding() {
    let session = grassSession()
    session.world.enqueue(.place(.house, at: tile(3, 4)))
    session.step()
    #expect(session.tileMenuViewModel(for: tile(3, 4)).items.contains(.demolish))
    #expect(!session.tileMenuViewModel(for: tile(8, 8)).items.contains(.demolish))
}

@Test("the dismiss entry closes the list")
@MainActor
func theDismissEntryClosesTheList() {
    let session = grassSession()
    #expect(session.tileMenuViewModel(for: tile(3, 4)).items.last == .dismiss)
}

@Test("scenario: menu emits dismiss for inspect entry")
@MainActor
func scenarioMenuEmitsDismissForInspectEntry() {
    let session = grassSession()
    session.selectTool(.place(.road))
    session.tileMenuRequest = TileMenuRequest(tile: tile(3, 4))
    session.applyMenuChoice(.dismiss, at: tile(3, 4))
    #expect(session.pendingPlacement == nil)
    #expect(session.selectedTool == .place(.road))
    #expect(session.tileMenuRequest == nil)
    #expect(session.world.pendingCommands.isEmpty)
}

@Test("scenario: long-press intent opens the tile menu request on iOS")
@MainActor
func scenarioLongPressIntentOpensTheTileMenuRequestOnIOS() {
    let session = grassSession()
    session.handleLongPress(at: tile(3, 4))
    #expect(session.tileMenuRequest == TileMenuRequest(tile: tile(3, 4)))
    #expect(session.selectedTile == tile(3, 4))
}

@Test("a long-press while a placement is pending opens no menu")
@MainActor
func aLongPressWhileAPlacementIsPendingOpensNoMenu() {
    let session = grassSession()
    session.beginPendingPlacement(kind: .house, at: tile(3, 4))
    session.handleLongPress(at: tile(7, 7))
    #expect(session.tileMenuRequest == nil)
}

@Test("scenario: menu build choice for a non-road kind enters pending placement")
@MainActor
func scenarioMenuBuildChoiceForANonRoadKindEntersPendingPlacement() {
    let session = grassSession()
    session.tileMenuRequest = TileMenuRequest(tile: tile(3, 4))
    session.applyMenuChoice(.build(.house), at: tile(3, 4))
    #expect(session.pendingPlacement?.kind == .house)
    #expect(session.pendingPlacement?.anchor == tile(3, 4))
    #expect(session.tileMenuRequest == nil)
    #expect(session.selectedTool == .inspect)
    #expect(session.world.pendingCommands.isEmpty)
}

@Test("scenario: menu build choice for road arms the road place tool")
@MainActor
func scenarioMenuBuildChoiceForRoadArmsTheRoadPlaceTool() {
    let session = grassSession()
    session.applyMenuChoice(.build(.road), at: tile(3, 4))
    #expect(session.selectedTool == .place(.road))
    #expect(session.pendingPlacement == nil)
}

@Test("the demolish choice enqueues a demolish at the tile at once")
@MainActor
func theDemolishChoiceEnqueuesADemolishAtOnce() {
    let session = grassSession()
    session.applyMenuChoice(.demolish, at: tile(3, 4))
    #expect(session.world.pendingCommands == [.demolish(at: tile(3, 4))])
    #expect(session.pendingPlacement == nil)
}

@Test("menu rows read as name and cost, or name and why not")
func menuRowsReadAsNameAndCostOrNameAndWhyNot() {
    #expect(TileMenuItem.build(.road, enabled: true, reason: nil).title == "Road — $\(BuildingCatalog.spec(for: .road).cost)")
    #expect(TileMenuItem.build(.mine, enabled: false, reason: "Needs Mining research").title == "Mine — Needs Mining research")
    #expect(TileMenuItem.demolish.title == "Demolish")
    #expect(TileMenuItem.dismiss.title == "Cancel")
}
