import CityCore
import Foundation
import SpriteKit
import Testing
@testable import CityRender2D

// Scenarios from openspec/changes/add-touch-first-placement/specs/rendering-2_5d.
// The UIKit recognizer needs a live view, so these drive the dispatch
// path the recognizer's `.began` callback calls.

private final class Source: IsoWorldDataSource {
    let snapshot: WorldSnapshot
    init(_ snapshot: WorldSnapshot) {
        self.snapshot = snapshot
    }

    func currentSnapshot() -> WorldSnapshot? {
        snapshot
    }
}

@MainActor
private final class Harness {
    let scene = IsoWorldScene()
    private(set) var intents: [Intent] = []

    init() {
        scene.dataSource = Source(World.fixtureWithTerrain(width: 8, height: 8, fill: .grass, seed: 1).snapshot())
        scene.intentSink = { [unowned self] in intents.append($0) }
    }
}

@Test("scenario: long-press inside map bounds dispatches longPressTile intent")
@MainActor
func scenarioLongPressInsideMapBoundsDispatchesLongPressTileIntent() {
    let harness = Harness()
    harness.scene.dispatchLongPress(at: IsoMath.screenPoint(forTile: TileCoordinate(x: 3, y: 4)))
    #expect(harness.intents == [.longPressTile(TileCoordinate(x: 3, y: 4))])
}

@Test("a long-press outside the map sends nothing")
@MainActor
func longPressOutsideTheMapSendsNothing() {
    let harness = Harness()
    harness.scene.dispatchLongPress(at: IsoMath.screenPoint(forTile: TileCoordinate(x: 12, y: 4)))
    #expect(harness.intents.isEmpty)
}
