import Foundation
import Testing
@testable import CityCore
@testable import CityUI

// The Apple TV wiring's platform-neutral half: what reaches the mapper,
// and which focus changes the host applies. Design D3, D7.

@MainActor
private func makeController() -> (TVRemoteController, [RemoteEffect]) {
    let session = GameSession(world: World.fixtureWithTerrain(width: 24, height: 24, fill: .grass, seed: 1))
    session.useAppleTVInput()
    session.world.camera = Camera(centerX: 10.5, centerY: 10.5)
    return (TVRemoteController(session: session), [])
}

@Test("Arming a building in the HUD starts its placement and returns focus to the map")
@MainActor
func armingABuildingInTheHUDStartsPlacement() {
    let (remote, _) = makeController()
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
    let (remote, _) = makeController()
    var effects: [RemoteEffect] = []
    remote.applyEffect = { effects.append($0) }
    remote.send(.focusChanged(.hud), at: 0)
    remote.toolChanged(to: .demolish, at: 1)
    #expect(remote.session.pendingPlacement == nil)
    #expect(effects == [.focusMap])
}

@Test("A tool change made on the map, such as Back putting a tool away, moves no focus")
@MainActor
func toolChangeOnTheMapMovesNoFocus() {
    let (remote, _) = makeController()
    var effects: [RemoteEffect] = []
    remote.applyEffect = { effects.append($0) }
    remote.toolChanged(to: .inspect, at: 0)
    #expect(effects.isEmpty)
}

@Test("A UIKit press that GameController already reported acts once")
@MainActor
func uiKitDuplicateActsOnce() {
    let (remote, _) = makeController()
    remote.send(ControllerSnapshot(dpad: .right), at: 1.0)
    remote.sendUIKit(.click(.right), at: 1.01)
    #expect(remote.session.reticleTile == TileCoordinate(x: 11, y: 10))
}

@Test("The tooltip follows the mapper on each tick")
@MainActor
func tooltipFollowsTheMapper() {
    let (remote, _) = makeController()
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
    let (remote, _) = makeController()
    var effects: [RemoteEffect] = []
    remote.applyEffect = { effects.append($0) }
    remote.focusMoved(toMap: false, at: 0)
    #expect(remote.mapper.focus == .hud)
    remote.focusMoved(toMap: false, at: 1)
    remote.focusMoved(toMap: true, at: 2)
    #expect(remote.mapper.focus == .map)
    #expect(effects.isEmpty, "the host already moved focus; nothing to apply")
}
