import Foundation
import Testing
@testable import CityCore
@testable import CityUI

// Scenarios from openspec/changes/add-minimap/specs/platform-shells/spec.md,
// Requirement: Apple TV map overview.

@MainActor
private func makeSession() -> GameSession {
    let session = GameSession(world: World.fixtureWithTerrain(width: 24, height: 24, fill: .grass, seed: 1))
    session.useAppleTVInput()
    session.isPaused = false
    session.world.camera = Camera(centerX: 10, centerY: 10, zoom: 1.0)
    return session
}

@MainActor
private func holdPlayPause(_ mapper: inout RemoteInputMapper, session: GameSession, at start: TimeInterval) {
    _ = mapper.handle(.playPauseDown, at: start, session: session)
    _ = mapper.handle(.tick, at: start + 0.5, session: session)
    _ = mapper.handle(.playPauseUp, at: start + 0.6, session: session)
}

@MainActor
private func press(_ input: RemoteInput, _ mapper: inout RemoteInputMapper, session: GameSession) {
    _ = mapper.handle(input, at: 0, session: session)
}

@Test("scenario: Play/Pause hold cycle reaches the overview")
@MainActor
func scenarioPlayPauseHoldCycleReachesTheOverview() {
    let session = makeSession()
    session.world.camera.setZoom(0.5)
    var mapper = RemoteInputMapper()
    holdPlayPause(&mapper, session: session, at: 0)
    #expect(session.overview != nil)
    #expect(session.world.camera.zoom == 0.5)
    holdPlayPause(&mapper, session: session, at: 2)
    #expect(session.overview == nil)
    #expect(session.world.camera.zoom == 2.0)
}

@Test("The zoom cycle's other stops are unchanged")
@MainActor
func zoomCycleOtherStops() {
    let session = makeSession()
    var mapper = RemoteInputMapper()
    session.world.camera.setZoom(2.0)
    holdPlayPause(&mapper, session: session, at: 0)
    #expect(session.world.camera.zoom == 1.0)
    holdPlayPause(&mapper, session: session, at: 2)
    #expect(session.world.camera.zoom == 0.5)
    #expect(session.overview == nil)
}

@Test("scenario: Controller X opens the overview")
@MainActor
func scenarioControllerXOpensTheOverview() throws {
    var adapter = GameControllerAdapter()
    let inputs = adapter.update(ControllerSnapshot(buttonX: true), at: 0)
    #expect(inputs == [.overview])
    let session = makeSession()
    var mapper = RemoteInputMapper()
    for input in inputs {
        press(input, &mapper, session: session)
    }
    let overview = try #require(session.overview)
    #expect(overview.cursorTile == TileCoordinate(x: 10, y: 10))
}

@Test("scenario: Select in the overview jumps the camera")
@MainActor
func scenarioSelectInTheOverviewJumpsTheCamera() {
    let session = makeSession()
    var mapper = RemoteInputMapper()
    press(.overview, &mapper, session: session)
    press(.click(.right), &mapper, session: session)
    press(.click(.right), &mapper, session: session)
    press(.selectDown, &mapper, session: session)
    press(.selectUp, &mapper, session: session)
    #expect(session.world.camera.centerX == 18 && session.world.camera.centerY == 10)
    #expect(session.overview == nil)
    #expect(session.selectedTile == nil, "the select jumps, it does not tap the map")
}

@Test("scenario: Back closes the overview")
@MainActor
func scenarioBackClosesTheOverview() {
    let session = makeSession()
    var mapper = RemoteInputMapper()
    press(.overview, &mapper, session: session)
    press(.click(.up), &mapper, session: session)
    press(.back, &mapper, session: session)
    #expect(session.overview == nil)
    #expect(session.world.camera.centerX == 10 && session.world.camera.centerY == 10)
    #expect(!session.isPaused)
}

@Test("scenario: Overview cursor stays on the map")
@MainActor
func scenarioOverviewCursorStaysOnTheMap() throws {
    let session = makeSession()
    session.world.camera = Camera(centerX: 1, centerY: 1, zoom: 1.0)
    var mapper = RemoteInputMapper()
    press(.overview, &mapper, session: session)
    press(.click(.left), &mapper, session: session)
    let cursor = try #require(session.overview?.cursorTile)
    #expect(session.world.contains(cursor))
    press(.swipe(dx: -5000, dy: -5000), &mapper, session: session)
    #expect(try session.world.contains(#require(session.overview?.cursorTile)))
}

@Test("A swipe in the overview moves the cursor, not the camera")
@MainActor
func swipeMovesCursorNotCamera() throws {
    let session = makeSession()
    var mapper = RemoteInputMapper()
    press(.overview, &mapper, session: session)
    press(.swipe(dx: 80, dy: 0), &mapper, session: session)
    let cursor = try #require(session.overview)
    #expect(cursor.cursorX > 10, "a swipe right moves the cursor right on screen")
    #expect(cursor.cursorY < 10)
    #expect(session.world.camera.centerX == 10 && session.world.camera.centerY == 10)
}

@Test("A select release without a press in the overview does not jump")
@MainActor
func straySelectUpIsIgnored() {
    let session = makeSession()
    var mapper = RemoteInputMapper()
    press(.overview, &mapper, session: session)
    press(.click(.right), &mapper, session: session)
    press(.selectUp, &mapper, session: session)
    #expect(session.overview != nil, "the release of the press that opened the overview must not close it")
    #expect(session.world.camera.centerX == 10)
    press(.selectDown, &mapper, session: session)
    press(.selectUp, &mapper, session: session)
    #expect(session.overview == nil)
    #expect(session.world.camera.centerX == 14)
}

@Test("Controller X toggles the overview and hands focus to the map")
@MainActor
func controllerXToggles() {
    let session = makeSession()
    var mapper = RemoteInputMapper()
    #expect(mapper.handle(.overview, at: 0, session: session) == [.focusMap])
    #expect(session.overview != nil)
    _ = mapper.handle(.overview, at: 0.1, session: session)
    #expect(session.overview == nil)
}

@Test("scenario: Map button hands the remote to the overview")
@MainActor
func mapButtonFocusesTheMap() {
    let session = makeSession()
    let remote = TVRemoteController(session: session)
    var effects: [RemoteEffect] = []
    remote.applyEffect = { effects.append($0) }
    remote.send(.playPauseDown, at: 0)
    remote.send(.playPauseUp, at: 0.1)
    #expect(remote.focus == .hud)
    effects.removeAll()
    remote.openOverview(at: 1)
    #expect(session.overview != nil)
    #expect(remote.focus == .map)
    #expect(effects == [.focusMap])
    remote.send(.back, at: 2)
    #expect(session.overview == nil, "Back closes the overview instead of leaving the app")
    #expect(remote.focus == .map)
}

@Test("A swipe moves the cursor as far on screen as the finger travels")
@MainActor
func swipeScalesWithTheOverview() throws {
    let session = makeSession()
    var mapper = RemoteInputMapper()
    press(.overview, &mapper, session: session)
    let scale = MapOverview.pointsPerUnit(span: 48)
    press(.swipe(dx: scale * 2, dy: 0), &mapper, session: session)
    let cursor = try #require(session.overview)
    // Two units of u right: one tile more x, one tile less y.
    #expect(abs(cursor.cursorX - 11) < 1e-9 && abs(cursor.cursorY - 9) < 1e-9)
}
