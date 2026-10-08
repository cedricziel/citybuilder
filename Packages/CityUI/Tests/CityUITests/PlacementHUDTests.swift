import CoreGraphics
import Foundation
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
