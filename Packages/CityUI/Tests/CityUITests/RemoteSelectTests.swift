import Foundation
import Testing
@testable import CityCore
@testable import CityUI

// Scenarios from openspec/changes/add-tvos-port/specs/tv-remote-controls
// (Reticle tooltip, Select and hold on the map, Placement follows the
// reticle) and rendering-2_5d (Input mapping, Palette-armed buildings).
// The mapper runs with an injected clock, so holds are exact.

@MainActor
private func makeSession(
    reticle: TileCoordinate = TileCoordinate(x: 10, y: 10),
    fill: TerrainType = .grass
) -> GameSession {
    let session = GameSession(world: World.fixtureWithTerrain(width: 24, height: 24, fill: fill, seed: 1))
    session.useAppleTVInput()
    moveReticle(session, to: reticle)
    return session
}

@MainActor
private func moveReticle(_ session: GameSession, to tile: TileCoordinate) {
    session.world.camera.centerX = Double(tile.x) + 0.5
    session.world.camera.centerY = Double(tile.y) + 0.5
}

@MainActor
private func addHouse(_ session: GameSession, at tile: TileCoordinate) {
    session.world.enqueue(.place(.house, at: tile))
    session.step()
}

@MainActor
private func pressSelect(
    at start: TimeInterval, for duration: TimeInterval, mapper: inout RemoteInputMapper, session: GameSession
) -> [RemoteEffect] {
    var effects = mapper.handle(.selectDown, at: start, session: session)
    effects += mapper.handle(.tick, at: start + duration, session: session)
    effects += mapper.handle(.selectUp, at: start + duration, session: session)
    return effects
}

private func tile(_ x: Int, _ y: Int) -> TileCoordinate {
    TileCoordinate(x: x, y: y)
}

@Test("scenario: Reticle rest on a building shows the tooltip")
@MainActor
func scenarioReticleRestOnABuildingShowsTheTooltip() {
    let session = makeSession()
    addHouse(session, at: tile(10, 10))
    var mapper = RemoteInputMapper()
    _ = mapper.handle(.tick, at: 0, session: session)
    #expect(mapper.tooltipBuilding(at: 0.3, session: session) == nil)
    _ = mapper.handle(.tick, at: 0.5, session: session)
    let house = session.world.occupiedTiles[tile(10, 10)]
    #expect(house != nil)
    #expect(mapper.tooltipBuilding(at: 0.5, session: session) == house)
}

@Test("scenario: No tooltip over empty ground")
@MainActor
func scenarioNoTooltipOverEmptyGround() {
    let session = makeSession()
    var mapper = RemoteInputMapper()
    _ = mapper.handle(.tick, at: 0, session: session)
    _ = mapper.handle(.tick, at: 0.5, session: session)
    #expect(mapper.tooltipBuilding(at: 0.5, session: session) == nil)
}

@Test("The reticle tooltip hides while a placement is pending")
@MainActor
func reticleTooltipHidesWhilePlacing() {
    let session = makeSession()
    addHouse(session, at: tile(10, 10))
    var mapper = RemoteInputMapper()
    _ = mapper.handle(.tick, at: 0, session: session)
    session.beginPendingPlacement(kind: .house, at: tile(10, 10))
    #expect(mapper.tooltipBuilding(at: 1, session: session) == nil)
}

@Test("scenario: Short select taps the reticle tile")
@MainActor
func scenarioShortSelectTapsTheReticleTile() {
    let session = makeSession()
    addHouse(session, at: tile(10, 10))
    var mapper = RemoteInputMapper()
    _ = pressSelect(at: 0, for: 0.2, mapper: &mapper, session: session)
    #expect(session.selectedTile == tile(10, 10))
    #expect(session.tileMenuRequest == nil)
}

@Test("scenario: Remote select dispatched as a tap on the reticle tile")
@MainActor
func scenarioRemoteSelectDispatchedAsATapOnTheReticleTile() {
    let session = makeSession(reticle: tile(4, 7))
    session.confirmsBuildingPlacement = false
    session.selectTool(.place(.road))
    var mapper = RemoteInputMapper()
    _ = pressSelect(at: 0, for: 0.1, mapper: &mapper, session: session)
    #expect(session.world.pendingCommands.contains(.place(.road, at: tile(4, 7))))
}

@Test("scenario: Holding select opens the tile menu")
@MainActor
func scenarioHoldingSelectOpensTheTileMenu() {
    let session = makeSession()
    var mapper = RemoteInputMapper()
    _ = mapper.handle(.selectDown, at: 0, session: session)
    _ = mapper.handle(.tick, at: 0.5, session: session)
    #expect(session.tileMenuRequest == TileMenuRequest(tile: tile(10, 10)))
    _ = mapper.handle(.selectUp, at: 0.6, session: session)
    #expect(session.selectedTile == tile(10, 10))
}

@Test("scenario: Holding select does nothing while a placement is pending")
@MainActor
func scenarioHoldingSelectDoesNothingWhileAPlacementIsPending() {
    let session = makeSession()
    session.beginPendingPlacement(kind: .house, at: tile(10, 10))
    var mapper = RemoteInputMapper()
    _ = pressSelect(at: 0, for: 0.5, mapper: &mapper, session: session)
    #expect(session.tileMenuRequest == nil)
    #expect(session.pendingPlacement?.kind == .house)
    #expect(session.world.pendingCommands.isEmpty)
}

@Test("scenario: Select on the selected building focuses its callout")
@MainActor
func scenarioSelectOnTheSelectedBuildingFocusesItsCallout() {
    let session = makeSession()
    addHouse(session, at: tile(10, 10))
    session.selectedTile = tile(10, 10)
    var mapper = RemoteInputMapper()
    let effects = pressSelect(at: 0, for: 0.1, mapper: &mapper, session: session)
    #expect(effects == [.focusInspector])
    #expect(mapper.focus == .hud)
}

@Test("scenario: Select adds a route stop in route mode")
@MainActor
func scenarioSelectAddsARouteStopInRouteMode() {
    let session = makeSession(fill: .water)
    session.beginRouteAuthoring()
    var mapper = RemoteInputMapper()
    _ = pressSelect(at: 0, for: 0.1, mapper: &mapper, session: session)
    #expect(session.routeAuthoring?.inProgressWaypoints == [.sea(position: Fixed2D(x: Fixed(10), y: Fixed(10)))])
}

@Test("scenario: Choosing a building starts placement at the reticle")
@MainActor
func scenarioChoosingABuildingStartsPlacementAtTheReticle() {
    let session = makeSession()
    var mapper = RemoteInputMapper()
    _ = mapper.handle(.focusChanged(.hud), at: 0, session: session)
    let effects = mapper.chooseBuilding(.house, at: 1, session: session)
    #expect(effects == [.focusMap])
    #expect(mapper.focus == .map)
    #expect(session.pendingPlacement?.kind == .house)
    #expect(session.pendingPlacement?.anchor == tile(10, 10))
}

@Test("scenario: Pending anchor follows the reticle")
@MainActor
func scenarioPendingAnchorFollowsTheReticle() {
    let session = makeSession()
    var mapper = RemoteInputMapper()
    _ = mapper.chooseBuilding(.house, at: 0, session: session)
    _ = mapper.handle(.click(.right), at: 1, session: session)
    #expect(session.pendingPlacement?.anchor == tile(11, 10))
}

@Test("scenario: Confirm places and starts the next placement")
@MainActor
func scenarioConfirmPlacesAndStartsTheNextPlacement() {
    let session = makeSession()
    session.world.economy.balance = 10000
    var mapper = RemoteInputMapper()
    _ = mapper.chooseBuilding(.house, at: 0, session: session)
    _ = pressSelect(at: 1, for: 0.1, mapper: &mapper, session: session)
    #expect(session.world.pendingCommands.contains(.place(.house, at: tile(10, 10))))
    #expect(session.pendingPlacement?.kind == .house)
    #expect(session.pendingPlacement?.anchor == session.reticleTile)
}

@Test("An invalid confirm keeps the placement pending")
@MainActor
func invalidConfirmKeepsThePlacementPending() {
    let session = makeSession(fill: .water)
    var mapper = RemoteInputMapper()
    _ = mapper.chooseBuilding(.house, at: 0, session: session)
    _ = pressSelect(at: 1, for: 0.1, mapper: &mapper, session: session)
    #expect(session.world.pendingCommands.isEmpty)
    #expect(session.pendingPlacement?.anchor == tile(10, 10))
}

@Test("Choosing the road arms the road tool instead of starting a placement")
@MainActor
func choosingTheRoadArmsTheTool() {
    let session = makeSession()
    var mapper = RemoteInputMapper()
    _ = mapper.chooseBuilding(.road, at: 0, session: session)
    #expect(session.selectedTool == .place(.road))
    #expect(session.pendingPlacement == nil)
}

@Test("scenario: Building placement is confirmed by default on Apple TV")
@MainActor
func scenarioBuildingPlacementIsConfirmedByDefaultOnAppleTV() {
    let session = GameSession(world: World.fixtureWithTerrain(width: 4, height: 4, fill: .grass, seed: 1))
    session.useAppleTVInput()
    #expect(session.confirmsBuildingPlacement)
    #expect(session.clampsCameraToMap)
}

@Test("A select held while focus moves to the HUD neither holds nor taps")
@MainActor
func selectHoldDoesNotLeakIntoTheHUD() {
    let session = makeSession()
    var mapper = RemoteInputMapper()
    _ = mapper.handle(.selectDown, at: 0, session: session)
    _ = mapper.handle(.focusChanged(.hud), at: 0.1, session: session)
    _ = mapper.handle(.tick, at: 0.5, session: session)
    _ = mapper.handle(.focusChanged(.map), at: 0.6, session: session)
    _ = mapper.handle(.selectUp, at: 0.7, session: session)
    #expect(session.tileMenuRequest == nil)
    #expect(session.selectedTile == nil)
}

@Test("Choosing a building clears the selection and does nothing after game over")
@MainActor
func chooseBuildingGoesThroughSelectTool() {
    let session = makeSession()
    session.selectedTile = tile(3, 3)
    var mapper = RemoteInputMapper()
    _ = mapper.chooseBuilding(.house, at: 0, session: session)
    #expect(session.selectedTile == nil)
    #expect(session.selectedTool == .place(.house))

    let over = makeSession()
    over.world.economy.gameOver = true
    var overMapper = RemoteInputMapper()
    _ = overMapper.handle(.focusChanged(.hud), at: 0, session: over)
    let effects = overMapper.chooseBuilding(.house, at: 1, session: over)
    #expect(over.selectedTool == .inspect)
    #expect(over.pendingPlacement == nil)
    #expect(effects.isEmpty)
}

@Test("Choosing the building the rail already armed keeps it armed")
@MainActor
func chooseAlreadyArmedBuilding() {
    let session = makeSession()
    session.selectTool(.place(.house))
    var mapper = RemoteInputMapper()
    _ = mapper.chooseBuilding(.house, at: 0, session: session)
    #expect(session.selectedTool == .place(.house))
    #expect(session.pendingPlacement?.kind == .house)
}
