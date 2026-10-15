import Foundation
import Testing
@testable import CityCore
@testable import CityUI

// Scenarios from openspec/changes/add-tvos-port/specs/tv-remote-controls:
// the reticle, panning, zoom and the map/HUD focus handover. The mapper
// is platform-neutral (design D4), so these run on the Mac with an
// injected clock; the session flags take their Apple TV values here.

@MainActor
private func makeSession(reticle: TileCoordinate = TileCoordinate(x: 10, y: 10)) -> GameSession {
    let session = GameSession(world: World.fixtureWithTerrain(width: 24, height: 24, fill: .grass, seed: 1))
    session.useAppleTVInput()
    session.world.camera = Camera(centerX: Double(reticle.x) + 0.5, centerY: Double(reticle.y) + 0.5)
    return session
}

private func tile(_ x: Int, _ y: Int) -> TileCoordinate {
    TileCoordinate(x: x, y: y)
}

@Test("scenario: Swipe on the map never moves focus")
@MainActor
func scenarioSwipeOnTheMapNeverMovesFocus() {
    let session = makeSession()
    var mapper = RemoteInputMapper()
    let before = session.world.camera
    let effects = mapper.handle(.swipe(dx: 0, dy: 200), at: 0, session: session)
    #expect(session.world.camera != before)
    #expect(effects.isEmpty)
    #expect(mapper.focus == .map)
}

@Test("scenario: Swipe in the HUD never pans")
@MainActor
func scenarioSwipeInTheHUDNeverPans() {
    let session = makeSession()
    var mapper = RemoteInputMapper()
    _ = mapper.handle(.focusChanged(.hud), at: 0, session: session)
    let before = session.world.camera
    _ = mapper.handle(.swipe(dx: -300, dy: 0), at: 0.1, session: session)
    #expect(session.world.camera == before)
}

@Test("scenario: Swipe past the corner keeps the reticle on the map")
@MainActor
func scenarioSwipePastTheCornerKeepsTheReticleOnTheMap() {
    let session = makeSession(reticle: tile(0, 0))
    var mapper = RemoteInputMapper()
    // The west corner is up and to the left on screen.
    for step in 0 ..< 20 {
        _ = mapper.handle(.swipe(dx: -400, dy: -400), at: Double(step) * 0.016, session: session)
    }
    #expect(session.reticleTile == tile(0, 0))
}

@Test("scenario: Reticle hints name the four steps")
@MainActor
func scenarioReticleHintsNameTheFourSteps() {
    let session = makeSession(reticle: tile(10, 10))
    #expect(session.reticleHint(.up) == tile(10, 9))
    #expect(session.reticleHint(.right) == tile(11, 10))
    #expect(session.reticleHint(.down) == tile(10, 11))
    #expect(session.reticleHint(.left) == tile(9, 10))
}

@Test("scenario: Directional click steps one tile")
@MainActor
func scenarioDirectionalClickStepsOneTile() {
    let session = makeSession(reticle: tile(10, 10))
    var mapper = RemoteInputMapper()
    _ = mapper.handle(.click(.right), at: 0, session: session)
    #expect(session.reticleTile == tile(11, 10))
}

@Test("A directional click off the map edge leaves the reticle on the edge tile")
@MainActor
func clickOffTheMapEdgeStaysOnTheEdge() {
    let session = makeSession(reticle: tile(23, 5))
    var mapper = RemoteInputMapper()
    _ = mapper.handle(.click(.right), at: 0, session: session)
    #expect(session.reticleTile == tile(23, 5))
}

@Test("scenario: Swipe pans by screen distance independent of zoom")
@MainActor
func scenarioSwipePansByScreenDistanceIndependentOfZoom() {
    func distanceMoved(atZoom zoom: Double) -> Double {
        let session = makeSession()
        session.world.camera.setZoom(zoom)
        let before = session.world.camera
        var mapper = RemoteInputMapper()
        _ = mapper.handle(.swipe(dx: 640, dy: 0), at: 0, session: session)
        return hypot(session.world.camera.centerX - before.centerX, session.world.camera.centerY - before.centerY)
    }
    let atOne = distanceMoved(atZoom: 1.0)
    let atTwo = distanceMoved(atZoom: 2.0)
    #expect(atOne > 0)
    #expect(abs(atTwo - atOne / 2) < 1e-9)
}

@Test("scenario: Zoom button multiplies by 1.5")
@MainActor
func scenarioZoomButtonMultipliesBy15() {
    let session = makeSession()
    session.zoomIn()
    #expect(session.world.camera.zoom == 1.5)
    session.zoomOut()
    #expect(session.world.camera.zoom == 1.0)
}

@Test("scenario: Zoom button respects the maximum")
@MainActor
func scenarioZoomButtonRespectsTheMaximum() {
    let session = makeSession()
    session.world.camera.setZoom(4.0)
    session.zoomIn()
    #expect(session.world.camera.zoom == 4.0)
}

@Test("scenario: Holding Play/Pause cycles the zoom levels")
@MainActor
func scenarioHoldingPlayPauseCyclesTheZoomLevels() {
    let session = makeSession()
    session.world.camera.setZoom(2.0)
    var mapper = RemoteInputMapper()
    _ = mapper.handle(.playPauseDown, at: 0, session: session)
    _ = mapper.handle(.tick, at: 0.5, session: session)
    let effects = mapper.handle(.playPauseUp, at: 0.6, session: session)
    #expect(session.world.camera.zoom == 1.0)
    #expect(effects.isEmpty, "a hold must not also move focus")
    #expect(mapper.focus == .map)
}

@Test("Holding Play/Pause steps 1.0 to 0.5, 0.5 to 2.0, and any other zoom to 1.0")
@MainActor
func holdingPlayPauseStepsThroughTheLevels() {
    let session = makeSession()
    for (from, to) in [(1.0, 0.5), (0.5, 2.0), (3.0, 1.0)] {
        session.world.camera.setZoom(from)
        session.cycleZoomLevel()
        #expect(session.world.camera.zoom == to)
    }
}

@Test("scenario: Play/Pause enters the HUD")
@MainActor
func scenarioPlayPauseEntersTheHUD() {
    let session = makeSession()
    var mapper = RemoteInputMapper()
    _ = mapper.handle(.playPauseDown, at: 0, session: session)
    let effects = mapper.handle(.playPauseUp, at: 0.1, session: session)
    #expect(effects == [.focusHUD])
    #expect(mapper.focus == .hud)
}

@Test("scenario: Play/Pause returns to the map")
@MainActor
func scenarioPlayPauseReturnsToTheMap() {
    let session = makeSession()
    var mapper = RemoteInputMapper()
    _ = mapper.handle(.focusChanged(.hud), at: 0, session: session)
    _ = mapper.handle(.playPauseDown, at: 1, session: session)
    let effects = mapper.handle(.playPauseUp, at: 1.1, session: session)
    #expect(effects == [.focusMap])
    #expect(mapper.focus == .map)
}

@Test("Controller triggers zoom continuously within the camera's bounds")
@MainActor
func triggersZoomWithinBounds() {
    let session = makeSession()
    var mapper = RemoteInputMapper()
    _ = mapper.handle(.zoomAxis(1), at: 0, session: session)
    #expect(session.world.camera.zoom > 1.0)
    for step in 0 ..< 500 {
        _ = mapper.handle(.zoomAxis(-1), at: Double(step), session: session)
    }
    #expect(session.world.camera.zoom == Camera.minZoom)
}

@Test("The Apple TV session defaults clamp the camera and confirm building placement")
@MainActor
func appleTVDefaults() {
    let session = GameSession(world: World.fixtureWithTerrain(width: 4, height: 4, fill: .grass, seed: 1))
    session.useAppleTVInput()
    #expect(session.clampsCameraToMap)
    #expect(session.confirmsBuildingPlacement)
}
