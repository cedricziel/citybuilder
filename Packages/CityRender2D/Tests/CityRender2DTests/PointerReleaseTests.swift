import CityCore
import Foundation
import SpriteKit
import Testing
@testable import CityRender2D

// Releasing the finger after a drag must not also send a tap: the drag
// already painted the last tile, so the tap is rejected as occupied and
// the HUD flashes a spurious "Tile occupied".

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
    let source = Source(World.fixtureWithTerrain(width: 8, height: 8, fill: .grass, seed: 1).snapshot())
    private(set) var intents: [Intent] = []

    init() {
        scene.dataSource = source
        scene.intentSink = { [unowned self] in intents.append($0) }
    }
}

@Test("release after a drag sends no tap")
@MainActor
func releaseAfterDragSendsNoTap() {
    let harness = Harness()
    let scene = harness.scene
    scene.handlePointerMoved(to: IsoMath.screenPoint(forTile: TileCoordinate(x: 2, y: 2)))
    scene.handlePointerMoved(to: IsoMath.screenPoint(forTile: TileCoordinate(x: 3, y: 2)))
    scene.handlePointerReleased(at: IsoMath.screenPoint(forTile: TileCoordinate(x: 3, y: 2)))
    #expect(harness.intents == [.dragTile(TileCoordinate(x: 2, y: 2)), .dragTile(TileCoordinate(x: 3, y: 2))])
}

@Test("release without a drag sends a tap")
@MainActor
func releaseWithoutDragSendsTap() {
    let harness = Harness()
    let scene = harness.scene
    scene.handlePointerReleased(at: IsoMath.screenPoint(forTile: TileCoordinate(x: 4, y: 1)))
    #expect(harness.intents == [.tapTile(TileCoordinate(x: 4, y: 1))])
}

@Test("a drag does not suppress the next plain tap")
@MainActor
func dragDoesNotSuppressNextTap() {
    let harness = Harness()
    let scene = harness.scene
    scene.handlePointerMoved(to: IsoMath.screenPoint(forTile: TileCoordinate(x: 2, y: 2)))
    scene.handlePointerReleased(at: IsoMath.screenPoint(forTile: TileCoordinate(x: 2, y: 2)))
    scene.handlePointerReleased(at: IsoMath.screenPoint(forTile: TileCoordinate(x: 5, y: 5)))
    #expect(harness.intents.last == .tapTile(TileCoordinate(x: 5, y: 5)))
}

@Test("a diagonal drag step paints a connecting tile")
@MainActor
func diagonalDragStepPaintsConnectingTile() {
    let harness = Harness()
    harness.scene.handlePointerMoved(to: IsoMath.screenPoint(forTile: TileCoordinate(x: 2, y: 2)))
    harness.scene.handlePointerMoved(to: IsoMath.screenPoint(forTile: TileCoordinate(x: 3, y: 3)))
    #expect(harness.intents == [
        .dragTile(TileCoordinate(x: 2, y: 2)),
        .dragTile(TileCoordinate(x: 3, y: 2)),
        .dragTile(TileCoordinate(x: 3, y: 3))
    ])
}

@Test("a long drag jump paints every tile between")
@MainActor
func longDragJumpPaintsEveryTileBetween() {
    let harness = Harness()
    harness.scene.handlePointerMoved(to: IsoMath.screenPoint(forTile: TileCoordinate(x: 1, y: 1)))
    harness.scene.handlePointerMoved(to: IsoMath.screenPoint(forTile: TileCoordinate(x: 4, y: 2)))
    let tiles = harness.intents.compactMap { intent -> TileCoordinate? in
        if case let .dragTile(tile) = intent { return tile }
        return nil
    }
    #expect(tiles.first == TileCoordinate(x: 1, y: 1))
    #expect(tiles.last == TileCoordinate(x: 4, y: 2))
    for (from, to) in zip(tiles, tiles.dropFirst()) {
        #expect(abs(from.x - to.x) + abs(from.y - to.y) == 1, "\(from) → \(to) is not one orthogonal step")
    }
}
