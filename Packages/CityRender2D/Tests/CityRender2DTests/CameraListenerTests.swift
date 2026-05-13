import CityCore
import Foundation
import SpriteKit
import Testing
@testable import CityRender2D

// Tests for spec `rendering-2_5d` "Camera listener callback"
// (`add-spatial-audio` M4). The scene exposes a `cameraListener` hook
// that fires at most once per wall-clock second with the camera's
// current `centerTile()`, so the audio listener stays in sync with the
// view without being driven per-frame.

@MainActor
private final class SnapshotSource: IsoWorldDataSource {
    var snapshot: WorldSnapshot
    init(snapshot: WorldSnapshot) {
        self.snapshot = snapshot
    }

    func currentSnapshot() -> WorldSnapshot? {
        snapshot
    }
}

@MainActor
private func sceneWithCamera(at centerX: Double, _ centerY: Double) -> (IsoWorldScene, SnapshotSource) {
    var world = World.fixtureWithTerrain(width: 4, height: 4, fill: .grass, seed: 1)
    world.camera = Camera(centerX: centerX, centerY: centerY, zoom: 1.0)
    let snapshot = world.snapshot()
    let dataSource = SnapshotSource(snapshot: snapshot)
    let scene = IsoWorldScene(size: CGSize(width: 800, height: 600))
    scene.dataSource = dataSource
    return (scene, dataSource)
}

@MainActor
@Test("scenario: listener push throttled to 1 Hz")
func scenarioListenerPushThrottledTo1Hz() {
    let (scene, _) = sceneWithCamera(at: 5.4, 6.2)
    var pushes: [TileCoordinate] = []
    scene.cameraListener = { pushes.append($0) }
    // 120 ticks across a 1-second window (ProMotion-style). First tick
    // fires immediately (no prior push); every subsequent tick is
    // throttled.
    for tick in 0 ..< 120 {
        scene.update(Double(tick) / 120.0)
    }
    #expect(pushes.count == 1, "expected exactly one push across a 1-second window of ticks, got \(pushes.count)")
}

@MainActor
@Test("scenario: callback receives current camera center")
func scenarioCallbackReceivesCurrentCameraCenter() {
    // Camera at (5.4, 6.2) → floor-based centerTile is (5, 6).
    let (scene, _) = sceneWithCamera(at: 5.4, 6.2)
    var pushes: [TileCoordinate] = []
    scene.cameraListener = { pushes.append($0) }
    scene.update(0)
    #expect(pushes == [TileCoordinate(x: 5, y: 6)])
}

@MainActor
@Test("scenario: no callback means no work")
func scenarioNoCallbackMeansNoWork() {
    // With cameraListener nil, the scene's per-frame tick does no
    // per-second timestamping. We can't directly observe "did no work",
    // but we can show that setting a listener later still produces the
    // first push (i.e. the throttle bookkeeping wasn't accidentally
    // running in the background and burning the budget).
    let (scene, _) = sceneWithCamera(at: 0, 0)
    for tick in 0 ..< 60 {
        scene.update(Double(tick) / 60.0)
    }
    var pushes: [TileCoordinate] = []
    scene.cameraListener = { pushes.append($0) }
    scene.update(1.0)
    #expect(pushes.count == 1, "first push after attaching the listener must fire")
}

@MainActor
@Test("listener fires once per second across multi-second window")
func listenerFiresOncePerSecondAcrossMultiSecondWindow() {
    // Demonstrates that the throttle's behavior is wall-clock-driven —
    // across 3 seconds at 60 ticks per second, we get 3 listener pushes.
    let (scene, _) = sceneWithCamera(at: 2.5, 3.5)
    var pushes: [TileCoordinate] = []
    scene.cameraListener = { pushes.append($0) }
    for tick in 0 ..< 180 {
        scene.update(Double(tick) / 60.0)
    }
    #expect(pushes.count == 3, "expected one push per second across 3 seconds, got \(pushes.count)")
}
