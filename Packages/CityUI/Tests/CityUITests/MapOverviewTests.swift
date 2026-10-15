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
