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

@MainActor
@Suite("Esc steps back on the Mac")
struct MacEscapeTests {
    @Test("scenario: Esc closes the overview first")
    func overviewFirst() {
        let session = makeSession()
        var state = StepBackState(overviewOpen: true)
        state.rail.toggle(.town)
        CityRootView.stepBack(session: session, state: &state)
        #expect(!state.overviewOpen)
        #expect(state.rail.openDrawer == .town)
    }

    @Test("scenario: Esc closes the drawer before the tool")
    func drawerBeforeTool() {
        let session = makeSession()
        var state = StepBackState()
        session.selectTool(.place(.road))
        state.rail.toggle(.town)
        CityRootView.stepBack(session: session, state: &state)
        #expect(state.rail.openDrawer == nil)
        #expect(session.selectedTool == .place(.road))
        CityRootView.stepBack(session: session, state: &state)
        #expect(session.selectedTool == .inspect)
        #expect(!session.isPaused)
    }

    @Test("scenario: Esc leaves route mode")
    func leavesRouteMode() {
        let session = makeSession()
        var state = StepBackState()
        session.beginRouteAuthoring()
        CityRootView.stepBack(session: session, state: &state)
        #expect(session.routeAuthoring == nil)
        #expect(!session.isPaused)
    }

    @Test("scenario: Esc folds the market before closing the inspector")
    func foldsDetailsThenClears() {
        let session = makeSession()
        var state = StepBackState(inspectorExpanded: true)
        session.selectedTile = TileCoordinate(x: 3, y: 3)
        CityRootView.stepBack(session: session, state: &state)
        #expect(!state.inspectorExpanded)
        #expect(session.selectedTile == TileCoordinate(x: 3, y: 3))
        CityRootView.stepBack(session: session, state: &state)
        #expect(session.selectedTile == nil)
        #expect(!session.isPaused)
    }

    @Test("scenario: Esc on an idle map pauses")
    func idlePauses() {
        let session = makeSession()
        var state = StepBackState()
        CityRootView.stepBack(session: session, state: &state)
        #expect(session.isPaused)
    }

    @Test("Esc cancels a pending placement and disarms its tool")
    func cancelsPendingPlacement() {
        let session = makeSession()
        session.confirmsBuildingPlacement = true
        var state = StepBackState()
        session.selectTool(.place(.house))
        session.handleTap(at: TileCoordinate(x: 5, y: 5))
        #expect(session.pendingPlacement != nil)
        CityRootView.stepBack(session: session, state: &state)
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

    @Test("A pan key moves one tile width of the map at any zoom")
    func panStepFollowsZoom() throws {
        #expect(MacMapInput.key("a", atZoom: 2) == .pan(CGSize(width: 128, height: 0)))
        let session = makeSession()
        session.world.camera.setZoom(2)
        try session.apply(#require(MacMapInput.key("a", atZoom: 2)))
        let camera = session.world.camera
        #expect(abs((camera.centerX - 12) - -1) < 1e-9 && abs((camera.centerY - 12) - 1) < 1e-9)
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

    @Test("scenario: Command-equals zooms in")
    func commandEqualsZoomsIn() {
        #expect(MacMapInput.commandKey("=") == .zoom(GameSession.zoomStep))
        #expect(MacMapInput.commandKey("q") == nil)
    }

    @Test("scenario: Plus zooms in")
    func plusZoomsIn() {
        #expect(MacMapInput.key("+") == .zoom(GameSession.zoomStep))
        #expect(MacMapInput.key("=") == .zoom(GameSession.zoomStep))
        #expect(MacMapInput.key("-") == .zoom(1 / GameSession.zoomStep))
    }
}

#if os(macOS)
import AppKit
import SpriteKit

@MainActor
@Suite("Mac map routing")
struct MacMapRoutingTests {
    @Test("scenario: Scrolling over the HUD leaves the map alone")
    func hudKeepsScroll() {
        let host = NSView()
        let map = SKView()
        let mapChild = NSView()
        let pill = NSView()
        host.addSubview(map)
        map.addSubview(mapChild)
        host.addSubview(pill)
        #expect(MacMapInput.map(containing: mapChild) === map)
        #expect(MacMapInput.map(containing: map) === map)
        #expect(MacMapInput.map(containing: pill) == nil)
        #expect(MacMapInput.map(containing: nil) == nil)
    }

    @Test("scenario: Momentum keeps the gesture's target")
    func momentumContinues() {
        #expect(!MacMapInput.continuesGesture(phase: .began, momentumPhase: []))
        #expect(!MacMapInput.continuesGesture(phase: .mayBegin, momentumPhase: []))
        #expect(MacMapInput.continuesGesture(phase: .changed, momentumPhase: []))
        #expect(MacMapInput.continuesGesture(phase: .ended, momentumPhase: []))
        #expect(MacMapInput.continuesGesture(phase: [], momentumPhase: .changed))
        #expect(!MacMapInput.continuesGesture(phase: [], momentumPhase: []))
    }
}

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

    @Test("scenario: Pause waits for the sheet")
    func pauseWaitsForSheet() {
        #expect(!GameMenuCommand.togglePause.isEnabled(hasSession: true, hasSheet: true))
        #expect(GameMenuCommand.togglePause.isEnabled(hasSession: true, hasSheet: false))
        #expect(GameMenuCommand.zoomIn.isEnabled(hasSession: true, hasSheet: true))
        #expect(!GameMenuCommand.zoomIn.isEnabled(hasSession: false, hasSheet: false))
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
