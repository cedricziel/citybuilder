import Foundation
import Testing
@testable import CityCore
@testable import CityUI

// Scenarios from openspec/changes/add-tvos-port/specs/tv-remote-controls
// / Game controller mapping. The adapter turns button-state snapshots
// into the mapper's events, so the mapping runs on the Mac (design D4).

@MainActor
private func makeSession() -> GameSession {
    let session = GameSession(world: World.fixtureWithTerrain(width: 24, height: 24, fill: .grass, seed: 1))
    session.useAppleTVInput()
    session.world.camera = Camera(centerX: 10.5, centerY: 10.5)
    return session
}

@MainActor
private func feed(
    _ snapshots: [ControllerSnapshot], adapter: inout GameControllerAdapter, mapper: inout RemoteInputMapper,
    session: GameSession
) {
    for (step, snapshot) in snapshots.enumerated() {
        let time = Double(step) * 0.1
        for input in adapter.update(snapshot, at: time) {
            _ = mapper.handle(input, at: time, session: session)
        }
    }
}

@Test("scenario: Controller A selects the reticle tile")
@MainActor
func scenarioControllerASelectsTheReticleTile() {
    let session = makeSession()
    var adapter = GameControllerAdapter()
    var mapper = RemoteInputMapper()
    feed(
        [ControllerSnapshot(), ControllerSnapshot(buttonA: true), ControllerSnapshot()],
        adapter: &adapter,
        mapper: &mapper,
        session: session
    )
    #expect(session.selectedTile == TileCoordinate(x: 10, y: 10))
}

@Test("A controller maps its buttons to the remote's events")
@MainActor
func controllerButtonMapping() {
    var adapter = GameControllerAdapter()
    #expect(adapter.update(ControllerSnapshot(buttonA: true), at: 0) == [.selectDown])
    #expect(adapter.update(ControllerSnapshot(), at: 0.1) == [.selectUp])
    #expect(adapter.update(ControllerSnapshot(buttonB: true), at: 0.2) == [.back])
    #expect(adapter.update(ControllerSnapshot(), at: 0.3).isEmpty)
    #expect(adapter.update(ControllerSnapshot(buttonY: true), at: 0.4) == [.playPauseDown])
    #expect(adapter.update(ControllerSnapshot(), at: 0.5) == [.playPauseUp])
    #expect(adapter.update(ControllerSnapshot(menu: true), at: 0.6) == [.menu])
    #expect(adapter.update(ControllerSnapshot(dpad: .left), at: 0.7) == [.click(.left)])
    #expect(adapter.update(ControllerSnapshot(dpad: .left), at: 0.8).isEmpty, "a held D-pad clicks once")
}

@Test("The left stick pans like a swipe outside its dead zone, and the triggers zoom")
@MainActor
func stickAndTriggers() {
    var adapter = GameControllerAdapter()
    #expect(adapter.update(ControllerSnapshot(leftStick: (0.05, 0)), at: 0).isEmpty)
    let pan = adapter.update(ControllerSnapshot(leftStick: (1, 0)), at: 0.1)
    #expect(pan.count == 1)
    if case let .swipe(dx, dy) = pan.first {
        #expect(dx > 0)
        #expect(dy == 0)
    } else {
        Issue.record("expected a swipe")
    }
    #expect(adapter.update(ControllerSnapshot(rightTrigger: 1), at: 0.2) == [.zoomAxis(1)])
    #expect(adapter.update(ControllerSnapshot(leftTrigger: 0.5), at: 0.3) == [.zoomAxis(-0.5)])
}

@Test("A Siri Remote touch pans by the change in touch position")
@MainActor
func remoteTouchPans() {
    var adapter = GameControllerAdapter()
    #expect(adapter.update(RemoteSnapshot(touch: (0.1, 0)), at: 0).isEmpty, "the first touch only anchors")
    let swipe = adapter.update(RemoteSnapshot(touch: (0.3, 0)), at: 0.05)
    guard case let .swipe(dx, dy) = swipe.first, swipe.count == 1 else {
        Issue.record("expected one swipe, got \(swipe)")
        return
    }
    #expect(abs(dx - 0.2 * GameControllerAdapter.touchGain) < 1e-9)
    #expect(dy == 0)
    #expect(adapter.update(RemoteSnapshot(), at: 0.1).isEmpty, "lifting the finger ends the swipe")
    #expect(adapter.update(RemoteSnapshot(touch: (0.6, 0)), at: 0.2).isEmpty, "a new touch anchors again")
}

@Test("A Siri Remote press on the clickpad's edge clicks; in its center it selects")
@MainActor
func remoteClickpadPresses() {
    var adapter = GameControllerAdapter()
    #expect(adapter.update(RemoteSnapshot(touch: (0, 0.9), pressed: true), at: 0) == [.click(.up)])
    #expect(adapter.update(RemoteSnapshot(), at: 0.1).isEmpty)
    #expect(adapter.update(RemoteSnapshot(touch: (0.1, 0.1), pressed: true), at: 0.2) == [.selectDown])
    #expect(adapter.update(RemoteSnapshot(), at: 0.3) == [.selectUp])
    #expect(adapter.update(RemoteSnapshot(playPause: true), at: 0.4) == [.playPauseDown])
    #expect(adapter.update(RemoteSnapshot(menu: true), at: 0.5) == [.playPauseUp, .back])
}

@Test("A UIKit press that repeats a GameController event within 50 ms is dropped")
@MainActor
func uiKitDuplicatesAreDropped() {
    var adapter = GameControllerAdapter()
    _ = adapter.update(ControllerSnapshot(buttonA: true), at: 1.0)
    #expect(adapter.uiKitPress(.selectDown, at: 1.02) == nil)
    #expect(adapter.uiKitPress(.selectDown, at: 2.0) == .selectDown, "the simulator remote only sends UIKit presses")
}
