import Foundation
import Testing
@testable import CityCore
@testable import CityUI

// Scenarios from openspec/changes/add-touch-first-placement/specs/rendering-2_5d.
// The iOS-only commit rule is a session flag (`confirmsBuildingPlacement`,
// on by default only on iOS), so these run on macOS too: tests that cover
// the touch flow switch it on, and every pre-existing test keeps the
// commit-on-click behaviour.

@MainActor
private func makeSession(confirms: Bool = true) -> GameSession {
    let session = GameSession(world: World.fixtureWithTerrain(width: 12, height: 12, fill: .grass, seed: 1))
    session.confirmsBuildingPlacement = confirms
    return session
}

private func tile(_ x: Int, _ y: Int) -> TileCoordinate {
    TileCoordinate(x: x, y: y)
}

@Test("scenario: beginPendingPlacement sets the pending state with the requested kind and anchor")
@MainActor
func scenarioBeginPendingPlacementSetsThePendingStateWithTheRequestedKindAndAnchor() {
    let session = makeSession()
    session.beginPendingPlacement(kind: .house, at: tile(3, 4))
    #expect(session.pendingPlacement == PendingPlacement(kind: .house, anchor: tile(3, 4), origin: tile(3, 4)))
}

@Test("scenario: nudgePendingPlacement moves the anchor along the iso direction")
@MainActor
func scenarioNudgePendingPlacementMovesTheAnchorAlongTheIsoDirection() {
    let session = makeSession()
    session.beginPendingPlacement(kind: .house, at: tile(5, 5))
    session.nudgePendingPlacement(.se)
    #expect(session.pendingPlacement?.anchor == tile(6, 5))
    session.nudgePendingPlacement(.sw)
    #expect(session.pendingPlacement?.anchor == tile(6, 6))
    session.nudgePendingPlacement(.nw)
    #expect(session.pendingPlacement?.anchor == tile(5, 6))
    session.nudgePendingPlacement(.ne)
    #expect(session.pendingPlacement?.anchor == tile(5, 5))
    #expect(session.pendingPlacement?.origin == tile(5, 5))
    #expect(session.world.pendingCommands.isEmpty)
}

@Test("scenario: nudgePendingPlacement is clamped to map bounds")
@MainActor
func scenarioNudgePendingPlacementIsClampedToMapBounds() {
    let session = makeSession()
    session.beginPendingPlacement(kind: .house, at: tile(0, 0))
    session.nudgePendingPlacement(.nw)
    session.nudgePendingPlacement(.ne)
    #expect(session.pendingPlacement?.anchor == tile(0, 0))
    session.beginPendingPlacement(kind: .house, at: tile(11, 11))
    session.nudgePendingPlacement(.se)
    session.nudgePendingPlacement(.sw)
    #expect(session.pendingPlacement?.anchor == tile(11, 11))
}

@Test("scenario: nudge placement clamps at the east edge")
@MainActor
func scenarioNudgePlacementClampsAtTheEastEdge() {
    let session = makeSession()
    session.beginPendingPlacement(kind: .house, at: tile(11, 5))
    session.nudgePendingPlacement(.se)
    #expect(session.pendingPlacement?.anchor == tile(11, 5))
}

@Test("scenario: nudge placement clamps at the north edge")
@MainActor
func scenarioNudgePlacementClampsAtTheNorthEdge() {
    let session = makeSession()
    session.beginPendingPlacement(kind: .house, at: tile(5, 0))
    session.nudgePendingPlacement(.ne)
    #expect(session.pendingPlacement?.anchor == tile(5, 0))
}

@Test("scenario: nudge placement intent moves the pending anchor")
@MainActor
func scenarioNudgePlacementIntentMovesThePendingAnchor() {
    let session = makeSession()
    session.beginPendingPlacement(kind: .house, at: tile(5, 5))
    session.nudgePendingPlacement(.se)
    #expect(session.pendingPlacement?.anchor == tile(6, 5))
    #expect(session.world.pendingCommands.isEmpty)
}

@Test("scenario: nudge without a pending placement does nothing")
@MainActor
func nudgeWithoutAPendingPlacementDoesNothing() {
    let session = makeSession()
    session.nudgePendingPlacement(.se)
    #expect(session.pendingPlacement == nil)
}

@Test("scenario: confirmPendingPlacement enqueues a place command at the pending anchor")
@MainActor
func scenarioConfirmPendingPlacementEnqueuesAPlaceCommandAtThePendingAnchor() {
    let session = makeSession()
    session.beginPendingPlacement(kind: .house, at: tile(3, 4))
    session.confirmPendingPlacement()
    #expect(session.world.pendingCommands == [.place(.house, at: tile(3, 4))])
}

@Test("scenario: confirmPendingPlacement clears the pending state")
@MainActor
func scenarioConfirmPendingPlacementClearsThePendingState() {
    let session = makeSession()
    session.beginPendingPlacement(kind: .house, at: tile(3, 4))
    session.confirmPendingPlacement()
    #expect(session.pendingPlacement == nil)
}

@Test("scenario: confirm placement intent enqueues a place command")
@MainActor
func scenarioConfirmPlacementIntentEnqueuesAPlaceCommand() {
    let session = makeSession()
    session.beginPendingPlacement(kind: .house, at: tile(3, 4))
    session.confirmPendingPlacement()
    #expect(session.world.pendingCommands == [.place(.house, at: tile(3, 4))])
    #expect(session.pendingPlacement == nil)
}

@Test("confirming a placement the world rejects keeps it pending and says why")
@MainActor
func confirmingARejectedPlacementKeepsItPendingAndSaysWhy() {
    let session = makeSession()
    session.world.enqueue(.place(.road, at: tile(3, 4)))
    session.step()
    session.beginPendingPlacement(kind: .house, at: tile(3, 4))
    session.confirmPendingPlacement()
    #expect(session.pendingPlacement?.anchor == tile(3, 4))
    #expect(session.world.pendingCommands.isEmpty)
    #expect(session.hud.rejectionMessage(at: Date()) == "Tile occupied")
}

@Test("scenario: cancelPendingPlacement clears the pending state without enqueuing")
@MainActor
func scenarioCancelPendingPlacementClearsThePendingStateWithoutEnqueuing() {
    let session = makeSession()
    session.beginPendingPlacement(kind: .house, at: tile(3, 4))
    session.cancelPendingPlacement()
    #expect(session.pendingPlacement == nil)
    #expect(session.world.pendingCommands.isEmpty)
}

@Test("scenario: cancel placement intent clears state without enqueuing")
@MainActor
func scenarioCancelPlacementIntentClearsStateWithoutEnqueuing() {
    let session = makeSession()
    session.beginPendingPlacement(kind: .house, at: tile(3, 4))
    session.cancelPendingPlacement()
    #expect(session.pendingPlacement == nil)
    #expect(session.world.pendingCommands.isEmpty)
}

@Test("the pending methods leave the armed tool alone")
@MainActor
func thePendingMethodsLeaveTheArmedToolAlone() {
    let session = makeSession()
    session.selectTool(.demolish)
    session.beginPendingPlacement(kind: .house, at: tile(3, 4))
    session.nudgePendingPlacement(.se)
    session.confirmPendingPlacement()
    #expect(session.selectedTool == .demolish)
}

@Test("scenario: handleTap is suppressed while a placement is pending")
@MainActor
func scenarioHandleTapIsSuppressedWhileAPlacementIsPending() {
    let session = makeSession()
    session.beginPendingPlacement(kind: .house, at: tile(3, 4))
    session.handleTap(at: tile(7, 7))
    #expect(session.pendingPlacement?.anchor == tile(3, 4))
    #expect(session.world.pendingCommands.isEmpty)
    #expect(session.selectedTool == .inspect)
    #expect(session.selectedTile == nil)
}

@Test("a drag does not paint while a placement is pending")
@MainActor
func aDragDoesNotPaintWhileAPlacementIsPending() {
    let session = makeSession()
    session.selectTool(.place(.road))
    session.beginPendingPlacement(kind: .house, at: tile(3, 4))
    session.handleDrag(at: tile(7, 7))
    #expect(session.world.pendingCommands.isEmpty)
}

@Test("scenario: ghostState reads from pendingPlacement when set")
@MainActor
func scenarioGhostStateReadsFromPendingPlacementWhenSet() {
    let session = makeSession()
    session.handleHover(at: tile(9, 9))
    session.beginPendingPlacement(kind: .house, at: tile(3, 4))
    let ghost = session.ghostState()
    #expect(ghost?.tile == tile(3, 4))
    #expect(ghost?.kind == .house)
    #expect(ghost?.valid == true)
}

@Test("the ghost of a pending placement turns invalid on an occupied tile")
@MainActor
func theGhostOfAPendingPlacementTurnsInvalidOnAnOccupiedTile() {
    let session = makeSession()
    session.world.enqueue(.place(.road, at: tile(3, 4)))
    session.step()
    session.beginPendingPlacement(kind: .house, at: tile(3, 4))
    #expect(session.ghostState()?.valid == false)
}

@Test("scenario: palette-armed building tap enters pending placement on iOS")
@MainActor
func scenarioPaletteArmedBuildingTapEntersPendingPlacementOnIOS() {
    let session = makeSession(confirms: true)
    session.selectTool(.place(.house))
    session.handleTap(at: tile(3, 4))
    #expect(session.pendingPlacement?.kind == .house)
    #expect(session.pendingPlacement?.anchor == tile(3, 4))
    #expect(session.world.pendingCommands.isEmpty)
}

@Test("scenario: palette-armed road tap or drag paints immediately on iOS")
@MainActor
func scenarioPaletteArmedRoadTapOrDragPaintsImmediatelyOnIOS() {
    let session = makeSession(confirms: true)
    session.selectTool(.place(.road))
    session.handleTap(at: tile(3, 4))
    session.handleDrag(at: tile(4, 4))
    #expect(session.world.pendingCommands == [.place(.road, at: tile(3, 4)), .place(.road, at: tile(4, 4))])
    #expect(session.pendingPlacement == nil)
}

@Test("demolish keeps painting immediately on iOS")
@MainActor
func demolishKeepsPaintingImmediatelyOnIOS() {
    let session = makeSession(confirms: true)
    session.selectTool(.demolish)
    session.handleTap(at: tile(3, 4))
    #expect(session.world.pendingCommands == [.demolish(at: tile(3, 4))])
}

@Test("a drag with a building armed does not paint buildings on iOS")
@MainActor
func aDragWithABuildingArmedDoesNotPaintBuildingsOnIOS() {
    let session = makeSession(confirms: true)
    session.selectTool(.place(.house))
    session.handleDrag(at: tile(3, 4))
    #expect(session.world.pendingCommands.isEmpty)
}

@Test("a palette-armed building tap still commits on click when confirmation is off")
@MainActor
func aPaletteArmedBuildingTapStillCommitsOnClickWhenConfirmationIsOff() {
    let session = makeSession(confirms: false)
    session.selectTool(.place(.house))
    session.handleTap(at: tile(3, 4))
    #expect(session.pendingPlacement == nil)
    #expect(session.world.pendingCommands == [.place(.house, at: tile(3, 4))])
}

@Test("confirmation defaults to the platform: on for iOS, off for macOS")
@MainActor
func confirmationDefaultsToThePlatform() {
    let session = GameSession(world: World.fixtureWithTerrain(width: 4, height: 4, fill: .grass, seed: 1))
    #if os(iOS)
    #expect(session.confirmsBuildingPlacement)
    #else
    #expect(!session.confirmsBuildingPlacement)
    #endif
}
