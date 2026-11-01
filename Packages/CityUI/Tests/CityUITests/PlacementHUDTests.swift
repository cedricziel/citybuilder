import CoreGraphics
import Foundation
import SwiftUI
import Testing
@testable import CityCore
@testable import CityUI

// Scenarios from openspec/changes/add-touch-first-placement/specs/rendering-2_5d
// (Placement HUD). Logic only: no SwiftUI geometry is asserted.

private func tile(_ x: Int, _ y: Int) -> TileCoordinate {
    TileCoordinate(x: x, y: y)
}

@MainActor
private func pendingSession() -> GameSession {
    let session = GameSession(world: World.fixtureWithTerrain(width: 12, height: 12, fill: .grass, seed: 1))
    session.beginPendingPlacement(kind: .house, at: tile(5, 5))
    return session
}

@Test("scenario: PlacementHUD renders four arrow buttons positioned around the pending tile")
@MainActor
func scenarioPlacementHUDRendersFourArrowButtonsPositionedAroundThePendingTile() throws {
    let session = pendingSession()
    let hud = try #require(session.placementHUD)
    #expect(hud.arrows == [.ne, .se, .sw, .nw])
    let offsets = hud.arrows.map { PlacementHUDLayout.arrowOffset(for: $0) }
    #expect(Set(offsets.map { "\($0.width),\($0.height)" }).count == 4)
}

@Test("the HUD exists only while a placement is pending")
@MainActor
func theHUDExistsOnlyWhileAPlacementIsPending() {
    let session = pendingSession()
    #expect(session.placementHUD != nil)
    session.cancelPendingPlacement()
    #expect(session.placementHUD == nil)
}

@Test("scenario: PlacementHUD checkmark button dispatches confirmPlacement")
@MainActor
func scenarioPlacementHUDCheckmarkButtonDispatchesConfirmPlacement() throws {
    let session = pendingSession()
    let hud = try #require(session.placementHUD)
    hud.confirm()
    #expect(session.pendingPlacement == nil)
    #expect(session.world.pendingCommands == [.place(.house, at: tile(5, 5))])
}

@Test("scenario: PlacementHUD cancel button dispatches cancelPlacement")
@MainActor
func scenarioPlacementHUDCancelButtonDispatchesCancelPlacement() throws {
    let session = pendingSession()
    let hud = try #require(session.placementHUD)
    hud.cancel()
    #expect(session.pendingPlacement == nil)
    #expect(session.world.pendingCommands.isEmpty)
}

@Test("scenario: PlacementHUD arrow button dispatches the matching nudgePlacement direction")
@MainActor
func scenarioPlacementHUDArrowButtonDispatchesTheMatchingNudgePlacementDirection() throws {
    let session = pendingSession()
    let hud = try #require(session.placementHUD)
    hud.nudge(.ne)
    #expect(session.pendingPlacement?.anchor == tile(5, 4))
}

@Test("an arrow that would leave the map is disabled")
@MainActor
func anArrowThatWouldLeaveTheMapIsDisabled() throws {
    let session = pendingSession()
    session.beginPendingPlacement(kind: .house, at: tile(0, 0))
    let hud = try #require(session.placementHUD)
    #expect(!hud.isEnabled(.ne))
    #expect(!hud.isEnabled(.nw))
    #expect(hud.isEnabled(.se))
    #expect(hud.isEnabled(.sw))
}

@Test("the checkmark says whether the placement would go through")
@MainActor
func theCheckmarkSaysWhetherThePlacementWouldGoThrough() throws {
    let session = pendingSession()
    #expect(try #require(session.placementHUD).isValid)
    session.world.enqueue(.place(.road, at: tile(5, 5)))
    session.step()
    #expect(try !#require(session.placementHUD).isValid)
}

@Test("an invalid placement names its reason beside the checkmark")
@MainActor
func anInvalidPlacementNamesItsReasonBesideTheCheckmark() throws {
    let session = pendingSession()
    #expect(try #require(session.placementHUD).reason == nil)
    session.world.enqueue(.place(.road, at: tile(5, 5)))
    session.step()
    #expect(try #require(session.placementHUD).reason == "Tile occupied")
}

@Test("a placement the city can't afford says so beside the checkmark")
@MainActor
func aPlacementTheCityCantAffordSaysSoBesideTheCheckmark() throws {
    let session = pendingSession()
    session.world.economy.balance = 0
    let hud = try #require(session.placementHUD)
    #expect(!hud.isValid)
    #expect(hud.reason == "Not enough money")
}

@Test("every HUD button is at least 44 points square")
func everyHUDButtonIsAtLeast44PointsSquare() {
    #expect(PlacementHUDLayout.buttonSize >= 44)
}

@Test("a tile at the camera center projects to the middle of the view")
func aTileAtTheCameraCenterProjectsToTheMiddleOfTheView() {
    let camera = Camera(centerX: 6, centerY: 4, zoom: 1)
    let point = PlacementHUDLayout.viewPoint(
        forTile: tile(6, 4), camera: camera, viewSize: CGSize(width: 800, height: 600)
    )
    #expect(point == CGPoint(x: 400, y: 300))
}

@Test("neighbouring tiles project along the iso diagonals and scale with zoom")
func neighbouringTilesProjectAlongTheIsoDiagonalsAndScaleWithZoom() {
    let size = CGSize(width: 800, height: 600)
    let camera = Camera(centerX: 6, centerY: 4, zoom: 1)
    let southEast = PlacementHUDLayout.viewPoint(forTile: tile(7, 4), camera: camera, viewSize: size)
    #expect(southEast == CGPoint(x: 432, y: 316))
    let northEast = PlacementHUDLayout.viewPoint(forTile: tile(6, 3), camera: camera, viewSize: size)
    #expect(northEast == CGPoint(x: 432, y: 284))
    let zoomed = Camera(centerX: 6, centerY: 4, zoom: 2)
    #expect(PlacementHUDLayout.viewPoint(forTile: tile(7, 4), camera: zoomed, viewSize: size) == CGPoint(x: 464, y: 332))
}

@Test("each arrow points along its iso diagonal on screen")
func eachArrowPointsAlongItsIsoDiagonalOnScreen() {
    let ne = PlacementHUDLayout.arrowOffset(for: .ne)
    let se = PlacementHUDLayout.arrowOffset(for: .se)
    let sw = PlacementHUDLayout.arrowOffset(for: .sw)
    let nw = PlacementHUDLayout.arrowOffset(for: .nw)
    // View y grows downward.
    #expect(ne.width > 0 && ne.height < 0)
    #expect(se.width > 0 && se.height > 0)
    #expect(sw.width < 0 && sw.height > 0)
    #expect(nw.width < 0 && nw.height < 0)
}

// iPhone 17 in landscape: 874 x 402 points, the Dynamic Island and the
// rounded corners inset both sides, the home indicator the bottom.
private let landscapePhone = CGSize(width: 874, height: 402)
private let landscapeInsets = EdgeInsets(top: 0, leading: 62, bottom: 21, trailing: 62)

private func safeRect(_ size: CGSize, _ insets: EdgeInsets) -> CGRect {
    CGRect(
        x: insets.leading, y: insets.top,
        width: size.width - insets.leading - insets.trailing,
        height: size.height - insets.top - insets.bottom
    )
}

private func buttonFrame(_ center: CGPoint) -> CGRect {
    let half = PlacementHUDLayout.buttonSize / 2
    return CGRect(x: center.x - half, y: center.y - half, width: half * 2, height: half * 2)
}

@Test("a ghost mid-screen keeps confirm and cancel right under its lowest arrows")
func aGhostMidScreenKeepsConfirmAndCancelRightUnderItsLowestArrows() {
    let center = CGPoint(x: 437, y: 120)
    let row = PlacementHUDLayout.actionRow(
        center: center, viewSize: landscapePhone, insets: landscapeInsets, reasonSize: nil
    )
    let below = center.y + PlacementHUDLayout.arrowRadius + PlacementHUDLayout.actionGap
    #expect(row.confirm == CGPoint(x: center.x + PlacementHUDLayout.actionGap, y: below))
    #expect(row.cancel == CGPoint(x: center.x - PlacementHUDLayout.actionGap, y: below))
}

@Test("iPhone landscape: a low ghost lifts confirm and cancel above the home indicator")
func iPhoneLandscapeALowGhostLiftsConfirmAndCancelAboveTheHomeIndicator() {
    // The playtest's shot 06: the ghost in the lower half of the screen.
    let center = CGPoint(x: 360, y: 300)
    let unclamped = center.y + PlacementHUDLayout.arrowRadius + PlacementHUDLayout.actionGap
    #expect(unclamped + PlacementHUDLayout.buttonSize / 2 > landscapePhone.height)
    let row = PlacementHUDLayout.actionRow(
        center: center, viewSize: landscapePhone, insets: landscapeInsets, reasonSize: nil
    )
    let safe = safeRect(landscapePhone, landscapeInsets)
    #expect(safe.contains(buttonFrame(row.confirm)))
    #expect(safe.contains(buttonFrame(row.cancel)))
    #expect(row.confirm.y == row.cancel.y)
}

@Test("iPhone landscape: the refusal reason stays on screen under the lifted buttons")
func iPhoneLandscapeTheRefusalReasonStaysOnScreenUnderTheLiftedButtons() {
    let center = CGPoint(x: 360, y: 300)
    let reasonHeight: CGFloat = 40
    let row = PlacementHUDLayout.actionRow(
        center: center, viewSize: landscapePhone, insets: landscapeInsets,
        reasonSize: CGSize(width: 180, height: reasonHeight)
    )
    let safe = safeRect(landscapePhone, landscapeInsets)
    #expect(safe.contains(buttonFrame(row.confirm)))
    #expect(row.reason.y - row.confirm.y == PlacementHUDLayout.reasonDrop)
    #expect(row.reason.y + reasonHeight / 2 <= safe.maxY)
}

@Test("a ghost off the bottom of the screen still leaves confirm and cancel reachable")
func aGhostOffTheBottomOfTheScreenStillLeavesConfirmAndCancelReachable() {
    let row = PlacementHUDLayout.actionRow(
        center: CGPoint(x: 437, y: 700), viewSize: landscapePhone, insets: landscapeInsets,
        reasonSize: CGSize(width: 120, height: 22)
    )
    let safe = safeRect(landscapePhone, landscapeInsets)
    #expect(safe.contains(buttonFrame(row.confirm)))
    #expect(row.reason.y + 11 <= safe.maxY)
}

@Test("a ghost at the side edge keeps confirm and cancel clear of the Dynamic Island")
func aGhostAtTheSideEdgeKeepsConfirmAndCancelClearOfTheDynamicIsland() {
    let safe = safeRect(landscapePhone, landscapeInsets)
    let leading = PlacementHUDLayout.actionRow(
        center: CGPoint(x: 20, y: 100), viewSize: landscapePhone, insets: landscapeInsets, reasonSize: nil
    )
    #expect(safe.contains(buttonFrame(leading.cancel)))
    #expect(leading.confirm.x - leading.cancel.x == PlacementHUDLayout.actionGap * 2)
    let trailing = PlacementHUDLayout.actionRow(
        center: CGPoint(x: 860, y: 100), viewSize: landscapePhone, insets: landscapeInsets, reasonSize: nil
    )
    #expect(safe.contains(buttonFrame(trailing.confirm)))
}

@Test("a wide refusal reason at the side edge stays clear of the Dynamic Island")
func aWideRefusalReasonAtTheSideEdgeStaysClearOfTheDynamicIsland() {
    let reason = CGSize(width: PlacementHUDLayout.reasonMaxWidth, height: 40)
    let row = PlacementHUDLayout.actionRow(
        center: CGPoint(x: 20, y: 100), viewSize: landscapePhone, insets: landscapeInsets, reasonSize: reason
    )
    #expect(row.reason.x - reason.width / 2 >= landscapeInsets.leading)
}
