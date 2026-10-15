import CoreGraphics
import Foundation
import SwiftUI
import Testing
@testable import CityCore
@testable import CityUI

// platform-shells scenarios of openspec/changes/mac-native-input: Esc
// steps back on the Mac, Mac trackpad and mouse camera, Mac keyboard
// camera and the Mac Game menu.

@MainActor
private func makeSession() -> GameSession {
    let session = GameSession(world: World.fixtureWithTerrain(width: 24, height: 24, fill: .grass, seed: 1))
    session.world.camera = Camera(centerX: 12, centerY: 12, zoom: 1)
    return session
}

/// The map point under a screen offset from the view's center, y down;
/// the inverse of `GameSession.handlePanDelta`'s projection.
@MainActor
private func mapPoint(under offset: CGSize, in session: GameSession) -> (x: Double, y: Double) {
    let camera = session.world.camera
    let overW = Double(offset.width) / 64
    let overH = Double(offset.height) / 32
    return (camera.centerX + (overW + overH) / camera.zoom, camera.centerY + (overH - overW) / camera.zoom)
}

/// The drawer and the inspector's details, as `CityRootView` holds them.
private func escapeState(expanded: Bool = false) -> (Binding<BuildRailModel>, Binding<Bool>) {
    var rail = BuildRailModel()
    var isExpanded = expanded
    return (Binding(get: { rail }, set: { rail = $0 }), Binding(get: { isExpanded }, set: { isExpanded = $0 }))
}

@MainActor
@Suite("Esc steps back on the Mac")
struct MacEscapeTests {
    @Test("scenario: Esc closes the drawer before the tool")
    func drawerBeforeTool() {
        let session = makeSession()
        let (rail, expanded) = escapeState()
        session.selectTool(.place(.road))
        rail.wrappedValue.toggle(.town)
        CityRootView.stepBack(session: session, rail: rail, inspectorExpanded: expanded)
        #expect(rail.wrappedValue.openDrawer == nil)
        #expect(session.selectedTool == .place(.road))
        CityRootView.stepBack(session: session, rail: rail, inspectorExpanded: expanded)
        #expect(session.selectedTool == .inspect)
        #expect(!session.isPaused)
    }

    @Test("scenario: Esc leaves route mode")
    func leavesRouteMode() {
        let session = makeSession()
        let (rail, expanded) = escapeState()
        session.beginRouteAuthoring()
        CityRootView.stepBack(session: session, rail: rail, inspectorExpanded: expanded)
        #expect(session.routeAuthoring == nil)
        #expect(!session.isPaused)
    }

    @Test("scenario: Esc folds the market before closing the inspector")
    func foldsDetailsThenClears() {
        let session = makeSession()
        let (rail, expanded) = escapeState(expanded: true)
        session.selectedTile = TileCoordinate(x: 3, y: 3)
        CityRootView.stepBack(session: session, rail: rail, inspectorExpanded: expanded)
        #expect(!expanded.wrappedValue)
        #expect(session.selectedTile == TileCoordinate(x: 3, y: 3))
        CityRootView.stepBack(session: session, rail: rail, inspectorExpanded: expanded)
        #expect(session.selectedTile == nil)
        #expect(!session.isPaused)
    }

    @Test("scenario: Esc on an idle map pauses")
    func idlePauses() {
        let session = makeSession()
        let (rail, expanded) = escapeState()
        CityRootView.stepBack(session: session, rail: rail, inspectorExpanded: expanded)
        #expect(session.isPaused)
    }

    @Test("Esc cancels a pending placement and disarms its tool")
    func cancelsPendingPlacement() {
        let session = makeSession()
        session.confirmsBuildingPlacement = true
        let (rail, expanded) = escapeState()
        session.selectTool(.place(.house))
        session.handleTap(at: TileCoordinate(x: 5, y: 5))
        #expect(session.pendingPlacement != nil)
        CityRootView.stepBack(session: session, rail: rail, inspectorExpanded: expanded)
        #expect(session.pendingPlacement == nil)
        #expect(session.selectedTool == .inspect)
    }
}

@MainActor
@Suite("Mac trackpad and mouse camera")
struct MacPointerCameraTests {
    @Test("scenario: Trackpad scroll pans")
    func trackpadScrollPans() {
        let action = MacMapInput.scroll(deltaX: 30, deltaY: -12, isPrecise: true, isInverted: true)
        #expect(action == .pan(CGSize(width: 30, height: -12)))
    }

    @Test("scenario: Mouse wheel zooms in")
    func wheelZoomsIn() {
        #expect(MacMapInput.scroll(deltaX: 0, deltaY: 1, isPrecise: false, isInverted: false) == .zoom(1.1))
        // Natural scrolling flips the reported delta; the wheel still zooms in.
        #expect(MacMapInput.scroll(deltaX: 0, deltaY: -1, isPrecise: false, isInverted: true) == .zoom(1.1))
    }

    @Test("scenario: Zoom keeps the point under the cursor")
    func zoomKeepsCursorPoint() {
        let session = makeSession()
        let cursor = CGSize(width: 200, height: -100)
        let before = mapPoint(under: cursor, in: session)
        session.zoom(by: 2, aroundScreenOffset: cursor)
        let after = mapPoint(under: cursor, in: session)
        #expect(session.world.camera.zoom == 2)
        #expect(abs(before.x - after.x) < 1e-9 && abs(before.y - after.y) < 1e-9)
    }

    @Test("scenario: Zoom stops at the limit")
    func zoomStopsAtLimit() {
        let session = makeSession()
        session.world.camera.setZoom(Camera.maxZoom)
        session.zoom(by: 1.5, aroundScreenOffset: CGSize(width: 200, height: -100))
        #expect(session.world.camera == Camera(centerX: 12, centerY: 12, zoom: Camera.maxZoom))
    }

    @Test("scenario: Right-drag pans")
    func rightDragPans() {
        #expect(MacMapInput.drag(deltaX: 8, deltaY: 5) == .pan(CGSize(width: 8, height: 5)))
    }
}

@MainActor
@Suite("Mac keyboard camera")
struct MacKeyboardCameraTests {
    @Test("scenario: Left arrow pans left")
    func leftArrowPans() throws {
        let leftArrow = try String(#require(UnicodeScalar(0xF702)))
        #expect(MacMapInput.key(leftArrow) == .pan(CGSize(width: 64, height: 0)))
        #expect(MacMapInput.key("a") == .pan(CGSize(width: 64, height: 0)))
        #expect(MacMapInput.key("A") == .pan(CGSize(width: 64, height: 0)))
    }

    @Test("Every pan key moves toward the side it names")
    func panKeys() throws {
        #expect(MacMapInput.key("d") == .pan(CGSize(width: -64, height: 0)))
        #expect(MacMapInput.key("w") == .pan(CGSize(width: 0, height: 64)))
        #expect(MacMapInput.key("s") == .pan(CGSize(width: 0, height: -64)))
        #expect(try MacMapInput.key(String(#require(UnicodeScalar(0xF700)))) == .pan(CGSize(width: 0, height: 64)))
        #expect(MacMapInput.key("r") == nil)
        #expect(MacMapInput.key("1") == nil)
    }

    @Test("scenario: Plus zooms in")
    func plusZoomsIn() {
        #expect(MacMapInput.key("+") == .zoom(GameSession.zoomStep))
        #expect(MacMapInput.key("=") == .zoom(GameSession.zoomStep))
        #expect(MacMapInput.key("-") == .zoom(1 / GameSession.zoomStep))
    }
}

#if os(macOS)
@MainActor
@Suite("Mac Game menu")
struct MacGameMenuTests {
    @Test("scenario: Game menu shortcuts")
    func shortcuts() {
        let shortcuts = GameMenuCommand.allCases.map { "\($0.key.character)\($0.modifiers.rawValue)" }
        let command = EventModifiers.command.rawValue
        #expect(shortcuts == [
            " 0", "1\(command)", "2\(command)", "3\(command)", "+\(command)", "-\(command)"
        ])
    }

    @Test("scenario: Space toggles pause")
    func spaceTogglesPause() {
        let session = makeSession()
        #expect(GameMenuCommand.togglePause.title(isPaused: false) == "Pause")
        GameMenuCommand.togglePause.perform(on: session)
        #expect(session.isPaused)
        #expect(GameMenuCommand.togglePause.title(isPaused: true) == "Resume")
        GameMenuCommand.togglePause.perform(on: session)
        #expect(!session.isPaused)
    }

    @Test("Choosing a speed from the menu resumes")
    func speedResumes() {
        let session = makeSession()
        session.isPaused = true
        GameMenuCommand.speed(.triple).perform(on: session)
        #expect(session.speed == .triple)
        #expect(!session.isPaused)
    }
}
#endif
