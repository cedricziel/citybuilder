import Foundation
import Testing
@testable import CityCore
@testable import CityUI

// Scenarios from openspec/changes/add-tvos-port/specs/tv-remote-controls:
// Road painting, Demolish acts on one building at a time, Back steps out
// one level at a time, and the controller's Menu button.

@MainActor
private func makeSession(
    reticle: TileCoordinate = TileCoordinate(x: 5, y: 5),
    fill: TerrainType = .grass
) -> GameSession {
    let session = GameSession(world: World.fixtureWithTerrain(width: 24, height: 24, fill: fill, seed: 1))
    session.useAppleTVInput()
    session.world.economy.balance = 100_000
    session.world.camera.centerX = Double(reticle.x) + 0.5
    session.world.camera.centerY = Double(reticle.y) + 0.5
    return session
}

@MainActor
private func select(_ mapper: inout RemoteInputMapper, _ session: GameSession, at time: TimeInterval) {
    _ = mapper.handle(.selectDown, at: time, session: session)
    _ = mapper.handle(.selectUp, at: time + 0.1, session: session)
}

private func tile(_ x: Int, _ y: Int) -> TileCoordinate {
    TileCoordinate(x: x, y: y)
}

@MainActor
private func roadCommands(_ session: GameSession) -> [TileCoordinate] {
    session.world.pendingCommands.compactMap { command in
        if case let .place(.road, at: tile) = command { return tile }
        return nil
    }
}

@Test("scenario: Painting a road with clicks")
@MainActor
func scenarioPaintingARoadWithClicks() {
    let session = makeSession(reticle: tile(5, 5))
    session.selectTool(.place(.road))
    var mapper = RemoteInputMapper()
    select(&mapper, session, at: 0)
    _ = mapper.handle(.click(.right), at: 1, session: session)
    _ = mapper.handle(.click(.right), at: 2, session: session)
    #expect(roadCommands(session) == [tile(5, 5), tile(6, 5), tile(7, 5)])
}

@Test("A second select stops painting")
@MainActor
func secondSelectStopsPainting() {
    let session = makeSession(reticle: tile(5, 5))
    session.selectTool(.place(.road))
    var mapper = RemoteInputMapper()
    select(&mapper, session, at: 0)
    select(&mapper, session, at: 1)
    _ = mapper.handle(.click(.right), at: 2, session: session)
    #expect(!session.isPaintingRoad)
    #expect(roadCommands(session) == [tile(5, 5)])
}

@Test("scenario: Swipes do not paint")
@MainActor
func scenarioSwipesDoNotPaint() {
    let session = makeSession(reticle: tile(5, 5))
    session.selectTool(.place(.road))
    var mapper = RemoteInputMapper()
    select(&mapper, session, at: 0)
    let before = roadCommands(session)
    _ = mapper.handle(.swipe(dx: 200, dy: 0), at: 1, session: session)
    #expect(session.reticleTile != tile(5, 5))
    #expect(roadCommands(session) == before)
}

@Test("scenario: Reticle shows painting")
@MainActor
func scenarioReticleShowsPainting() {
    let session = makeSession()
    #expect(session.reticleStyle == .idle)
    session.selectTool(.place(.road))
    var mapper = RemoteInputMapper()
    select(&mapper, session, at: 0)
    #expect(session.reticleStyle == .painting)
    session.selectTool(.demolish)
    #expect(session.reticleStyle == .demolish)
}

@Test("scenario: Demolish removes only the building under the reticle")
@MainActor
func scenarioDemolishRemovesOnlyTheBuildingUnderTheReticle() {
    let session = makeSession(reticle: tile(5, 5))
    session.world.enqueue(.place(.house, at: tile(5, 5)))
    session.world.enqueue(.place(.house, at: tile(7, 5)))
    session.step()
    session.selectTool(.demolish)
    var mapper = RemoteInputMapper()
    select(&mapper, session, at: 0)
    _ = mapper.handle(.click(.right), at: 1, session: session)
    _ = mapper.handle(.click(.right), at: 2, session: session)
    #expect(session.world.pendingCommands == [.demolish(at: tile(5, 5))])
}

@Test("scenario: Back on an idle map opens the pause menu")
@MainActor
func scenarioBackOnAnIdleMapOpensThePauseMenu() {
    let session = makeSession()
    var mapper = RemoteInputMapper()
    _ = mapper.handle(.back, at: 0, session: session)
    #expect(session.isPaused)
}

@Test("scenario: Back stops painting before putting the tool away")
@MainActor
func scenarioBackStopsPaintingBeforePuttingTheToolAway() {
    let session = makeSession()
    session.selectTool(.place(.road))
    var mapper = RemoteInputMapper()
    select(&mapper, session, at: 0)
    _ = mapper.handle(.back, at: 1, session: session)
    #expect(!session.isPaintingRoad)
    #expect(session.selectedTool == .place(.road))
    _ = mapper.handle(.back, at: 2, session: session)
    #expect(session.selectedTool == .inspect)
    #expect(!session.isPaused)
}

@Test("scenario: Back cancels placement and returns to inspect")
@MainActor
func scenarioBackCancelsPlacementAndReturnsToInspect() {
    let session = makeSession()
    var mapper = RemoteInputMapper()
    _ = mapper.chooseBuilding(.house, at: 0, session: session)
    _ = mapper.handle(.back, at: 1, session: session)
    #expect(session.pendingPlacement == nil)
    #expect(session.world.pendingCommands.isEmpty)
    #expect(session.selectedTool == .inspect)
}

@Test("scenario: Back in route mode removes the last stop")
@MainActor
func scenarioBackInRouteModeRemovesTheLastStop() {
    let session = makeSession(fill: .water)
    session.beginRouteAuthoring()
    var mapper = RemoteInputMapper()
    select(&mapper, session, at: 0)
    _ = mapper.handle(.click(.right), at: 1, session: session)
    select(&mapper, session, at: 2)
    #expect(session.routeAuthoring?.inProgressWaypoints.count == 2)
    _ = mapper.handle(.back, at: 3, session: session)
    #expect(session.routeAuthoring?.inProgressWaypoints.count == 1)
    _ = mapper.handle(.back, at: 4, session: session)
    _ = mapper.handle(.back, at: 5, session: session)
    #expect(session.routeAuthoring == nil, "Back after the last stop leaves route mode")
}

@Test("Back closes the tile menu, then clears the selection, then pauses")
@MainActor
func backClosesTheTileMenuThenClearsTheSelection() {
    let session = makeSession()
    session.handleLongPress(at: tile(5, 5))
    var mapper = RemoteInputMapper()
    _ = mapper.handle(.back, at: 0, session: session)
    #expect(session.tileMenuRequest == nil)
    #expect(session.selectedTile == tile(5, 5))
    _ = mapper.handle(.back, at: 1, session: session)
    #expect(session.selectedTile == nil)
    #expect(!session.isPaused)
    _ = mapper.handle(.back, at: 2, session: session)
    #expect(session.isPaused)
}

@Test("Back in the HUD returns focus to the map")
@MainActor
func backInTheHUDReturnsToTheMap() {
    let session = makeSession()
    var mapper = RemoteInputMapper()
    _ = mapper.handle(.focusChanged(.hud), at: 0, session: session)
    let effects = mapper.handle(.back, at: 1, session: session)
    #expect(effects == [.focusMap])
    #expect(mapper.focus == .map)
    #expect(!session.isPaused)
}

@Test("scenario: Back on the pause menu resumes")
@MainActor
func scenarioBackOnThePauseMenuResumes() {
    let session = makeSession()
    session.speed = .triple
    var mapper = RemoteInputMapper()
    _ = mapper.handle(.back, at: 0, session: session)
    #expect(session.isPaused)
    _ = mapper.handle(.back, at: 1, session: session)
    #expect(!session.isPaused)
    #expect(session.speed == .triple)
}

@Test("scenario: Back on the title screen is left to the system")
func scenarioBackOnTheTitleScreenIsLeftToTheSystem() {
    #expect(!RemoteInputMapper.handlesBack(on: .title))
    #expect(RemoteInputMapper.handlesBack(on: .game))
}

@Test("scenario: Controller Menu opens the pause menu")
@MainActor
func scenarioControllerMenuOpensThePauseMenu() {
    let session = makeSession()
    var mapper = RemoteInputMapper()
    _ = mapper.chooseBuilding(.house, at: 0, session: session)
    _ = mapper.handle(.menu, at: 1, session: session)
    #expect(session.isPaused)
}
