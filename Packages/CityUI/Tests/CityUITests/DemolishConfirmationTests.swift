import Foundation
import Testing
@testable import CityCore
@testable import CityUI

// Scenarios from openspec/changes/demolish-refund-confirm (platform-shells
// / Demolish asks first).

private let sawmillAnchor = TileCoordinate(x: 2, y: 2)
private let roadTile = TileCoordinate(x: 8, y: 8)

@MainActor
private func session(with kind: BuildingKind = .sawmill, state: BuildingState = .operational) -> GameSession {
    var world = World.fixtureWithTerrain(width: 24, height: 24, fill: .grass, seed: 1)
    for (id, kind, anchor, state) in [(1, kind, sawmillAnchor, state), (2, .road, roadTile, .operational)] {
        let entity = EntityID(raw: UInt32(id))
        world.buildings[entity] = Building(id: entity, kind: kind, anchor: anchor, state: state)
        for tile in BuildingCatalog.spec(for: kind).footprint.tiles(anchor: anchor) {
            world.occupiedTiles[tile] = entity
        }
    }
    world.nextEntityRaw = 3
    return GameSession(world: world)
}

@MainActor
@Test("scenario: demolishing a standing building asks first")
func scenarioDemolishingAStandingBuildingAsksFirst() throws {
    let session = session()
    session.selectedTool = .demolish
    session.handleTap(at: sawmillAnchor)
    #expect(session.world.pendingCommands.isEmpty)
    let request = try #require(session.demolishRequest)
    #expect(request.title == "Demolish Sawmill?")
    #expect(request.message == "You get $60 back.")
}

@MainActor
@Test("a demolish that refunds nothing says so")
func aDemolishThatRefundsNothingSaysSo() {
    let session = session(with: .townCenter)
    session.applyMenuChoice(.demolish, at: sawmillAnchor)
    #expect(session.demolishRequest?.message == "You get nothing back.")
    #expect(session.world.pendingCommands.isEmpty)
}

@MainActor
@Test("scenario: confirming demolishes, cancelling keeps the building")
func scenarioConfirmingDemolishesCancellingKeepsTheBuilding() {
    let session = session()
    session.selectedTool = .demolish
    session.handleTap(at: sawmillAnchor)
    session.cancelDemolish()
    #expect(session.demolishRequest == nil)
    #expect(session.world.pendingCommands.isEmpty)

    session.handleTap(at: TileCoordinate(x: 3, y: 3))
    session.confirmDemolish()
    #expect(session.demolishRequest == nil)
    #expect(session.world.pendingCommands == [.demolish(at: TileCoordinate(x: 3, y: 3))])
}

@MainActor
@Test("scenario: roads, ruins and burning buildings go at once", arguments: [
    (BuildingKind.ruins, BuildingState.operational), (.house, .burning)
])
func scenarioRoadsRuinsAndBurningBuildingsGoAtOnce(kind: BuildingKind, state: BuildingState) {
    let session = session(with: kind, state: state)
    session.selectedTool = .demolish
    session.handleTap(at: roadTile)
    session.handleTap(at: sawmillAnchor)
    #expect(session.demolishRequest == nil)
    #expect(session.world.pendingCommands == [.demolish(at: roadTile), .demolish(at: sawmillAnchor)])
}

@MainActor
@Test("scenario: dragging the demolish tool skips standing buildings")
func scenarioDraggingTheDemolishToolSkipsStandingBuildings() {
    let session = session()
    session.selectedTool = .demolish
    session.handleDrag(at: roadTile)
    session.handleDrag(at: sawmillAnchor)
    #expect(session.demolishRequest == nil)
    #expect(session.world.pendingCommands == [.demolish(at: roadTile)])
}

@MainActor
@Test("the tile menu's Demolish asks first for a standing building")
func theTileMenusDemolishAsksFirst() {
    let session = session()
    session.applyMenuChoice(.demolish, at: sawmillAnchor)
    #expect(session.demolishRequest?.tile == sawmillAnchor)
    #expect(session.world.pendingCommands.isEmpty)
}

@MainActor
@Test("no demolish confirmation opens after game over")
func noDemolishConfirmationAfterGameOver() {
    let session = session()
    session.world.economy.gameOver = true
    session.selectedTool = .demolish
    session.handleTap(at: sawmillAnchor)
    #expect(session.demolishRequest == nil)
}

@MainActor
@Test("scenario: the remote moves to the demolish confirmation")
func scenarioTheRemoteMovesToTheDemolishConfirmation() {
    let session = session()
    session.useAppleTVInput()
    session.world.camera = Camera(centerX: 2.5, centerY: 2.5)
    let remote = TVRemoteController(session: session)
    var effects: [RemoteEffect] = []
    remote.applyEffect = { effects.append($0) }
    session.selectedTool = .demolish
    remote.send(.selectDown, at: 0)
    remote.send(.selectUp, at: 0.1)
    #expect(session.demolishRequest != nil)
    #expect(remote.focus == .hud)
    #expect(effects == [.focusHUD])

    session.cancelDemolish()
    remote.demolishConfirmationClosed(at: 1)
    #expect(remote.focus == .map)
    #expect(effects == [.focusHUD, .focusMap])
}
