import Foundation
import Testing
@testable import CityCore
@testable import CityUI

// The Apple TV wiring's platform-neutral half: what reaches the mapper,
// and which focus changes the host applies. Design D3, D7.

@MainActor
private func makeController() -> TVRemoteController {
    let session = GameSession(world: World.fixtureWithTerrain(width: 24, height: 24, fill: .grass, seed: 1))
    session.useAppleTVInput()
    session.world.camera = Camera(centerX: 10.5, centerY: 10.5)
    return TVRemoteController(session: session)
}

@Test("Arming a building in the HUD starts its placement and returns focus to the map")
@MainActor
func armingABuildingInTheHUDStartsPlacement() {
    let remote = makeController()
    var effects: [RemoteEffect] = []
    remote.applyEffect = { effects.append($0) }
    remote.send(.focusChanged(.hud), at: 0)
    remote.toolChanged(to: .place(.house), at: 1)
    #expect(remote.session.pendingPlacement?.anchor == TileCoordinate(x: 10, y: 10))
    #expect(effects == [.focusMap])
    #expect(remote.mapper.focus == .map)
}

@Test("Arming road or demolish in the HUD returns focus to the map without a placement")
@MainActor
func armingRoadOrDemolishReturnsToTheMap() {
    let remote = makeController()
    var effects: [RemoteEffect] = []
    remote.applyEffect = { effects.append($0) }
    remote.send(.focusChanged(.hud), at: 0)
    remote.toolChanged(to: .demolish, at: 1)
    #expect(remote.session.pendingPlacement == nil)
    #expect(effects == [.focusMap])

    remote.send(.focusChanged(.hud), at: 2)
    remote.toolChanged(to: .place(.road), at: 3)
    #expect(remote.session.pendingPlacement == nil)
    #expect(!remote.session.isPaintingRoad, "painting starts with a select on the map, not when the tool is armed")
    #expect(effects == [.focusMap, .focusMap])
}

@Test("A tool change made on the map, such as Back putting a tool away, moves no focus")
@MainActor
func toolChangeOnTheMapMovesNoFocus() {
    let remote = makeController()
    var effects: [RemoteEffect] = []
    remote.applyEffect = { effects.append($0) }
    remote.toolChanged(to: .inspect, at: 0)
    #expect(effects.isEmpty)
}

@Test("A UIKit press that GameController already reported acts once")
@MainActor
func uiKitDuplicateActsOnce() {
    let remote = makeController()
    remote.send(ControllerSnapshot(dpad: .right), from: 1, at: 1.0)
    remote.sendUIKit(.click(.right), at: 1.01)
    #expect(remote.session.reticleTile == TileCoordinate(x: 11, y: 10))
}

@Test("The tooltip follows the mapper on each tick")
@MainActor
func tooltipFollowsTheMapper() {
    let remote = makeController()
    remote.session.world.enqueue(.place(.house, at: TileCoordinate(x: 10, y: 10)))
    remote.session.step()
    remote.send(.tick, at: 0)
    #expect(remote.tooltipBuilding == nil)
    remote.send(.tick, at: 0.6)
    #expect(remote.tooltipBuilding == remote.session.world.occupiedTiles[TileCoordinate(x: 10, y: 10)])
}

@Test("A focus move the system makes reaches the mapper once")
@MainActor
func systemFocusMovesReachTheMapper() {
    let remote = makeController()
    var effects: [RemoteEffect] = []
    remote.applyEffect = { effects.append($0) }
    remote.focusMoved(toMap: false, at: 0)
    #expect(remote.mapper.focus == .hud)
    remote.focusMoved(toMap: false, at: 1)
    remote.focusMoved(toMap: true, at: 2)
    #expect(remote.mapper.focus == .map)
    #expect(effects.isEmpty, "the host already moved focus; nothing to apply")
}

@Test("Controller and remote input is dropped while the HUD owns the remote")
@MainActor
func controllerInputIsDroppedInTheHUD() {
    let remote = makeController()
    var effects: [RemoteEffect] = []
    remote.applyEffect = { effects.append($0) }
    remote.send(.focusChanged(.hud), at: 0)
    remote.send(ControllerSnapshot(buttonB: true), from: 1, at: 1)
    remote.send(ControllerSnapshot(buttonY: true), from: 1, at: 1.1)
    remote.send(ControllerSnapshot(), from: 1, at: 1.2)
    remote.send(RemoteSnapshot(menu: true), from: 2, at: 1.3)
    #expect(effects.isEmpty, "the focus engine handles these presses in the HUD")
    #expect(remote.focus == .hud)
    #expect(!remote.session.isPaused)
}

@Test("A press held when the HUD took the remote does not release on the map")
@MainActor
func heldPressDoesNotLeakAcrossFocus() {
    let remote = makeController()
    remote.send(.focusChanged(.hud), at: 0)
    remote.send(ControllerSnapshot(buttonA: true), from: 1, at: 1)
    remote.send(.focusChanged(.map), at: 2)
    remote.send(ControllerSnapshot(), from: 1, at: 3)
    #expect(remote.session.selectedTile == nil)
}

@Test("Each controller keeps its own button state")
@MainActor
func eachControllerKeepsItsOwnState() {
    let remote = makeController()
    remote.send(ControllerSnapshot(buttonA: true), from: 1, at: 0)
    remote.send(ControllerSnapshot(), from: 2, at: 0.1)
    #expect(remote.session.selectedTile == nil, "a second controller's idle snapshot is not a release of the first's A")
    remote.send(ControllerSnapshot(), from: 1, at: 0.2)
    #expect(remote.session.selectedTile == TileCoordinate(x: 10, y: 10))
}

@Test("A controller that disconnects mid-press releases its buttons")
@MainActor
func disconnectReleasesHeldButtons() {
    let remote = makeController()
    remote.send(ControllerSnapshot(buttonA: true), from: 1, at: 0)
    remote.controllerDisconnected(1, at: 0.1)
    #expect(remote.session.selectedTile == TileCoordinate(x: 10, y: 10))
    remote.send(ControllerSnapshot(buttonY: true), from: 1, at: 1)
    remote.controllerDisconnected(1, at: 1.1)
    #expect(remote.focus == .hud, "the release of Y counts as a short Play/Pause press")
}

@Test("Focus is published only when it changes")
@MainActor
func focusIsPublished() {
    let remote = makeController()
    #expect(remote.focus == .map)
    remote.send(.playPauseDown, at: 0)
    remote.send(.playPauseUp, at: 0.1)
    #expect(remote.focus == .hud)
}

@Test("Select on the selected building sends focus to the callout until it takes it")
@MainActor
func selectOnSelectedBuildingFocusesTheCallout() {
    let remote = makeController()
    remote.session.world.enqueue(.place(.house, at: TileCoordinate(x: 10, y: 10)))
    remote.session.step()
    remote.session.selectedTile = TileCoordinate(x: 10, y: 10)
    var effects: [RemoteEffect] = []
    remote.applyEffect = { effects.append($0) }
    remote.send(.selectDown, at: 0)
    remote.send(.selectUp, at: 0.1)
    #expect(effects == [.focusInspector])
    #expect(remote.focusesInspector)
    remote.inspectorTookFocus()
    #expect(!remote.focusesInspector)
}
