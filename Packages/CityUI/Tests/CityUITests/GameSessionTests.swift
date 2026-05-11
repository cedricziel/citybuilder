import CityCore
import CoreGraphics
import Testing
@testable import CityUI

// Tests for the GameSession gesture handlers. These are the load-bearing
// behaviors the user noticed when the world wasn't following their finger.

@MainActor
@Test("session: drag right moves world right under the finger")
func sessionDragRightMovesWorld() {
    let session = GameSession(
        world: World.fixtureWithTerrain(width: 16, height: 16, fill: .grass, seed: 1)
    )
    session.world.camera = Camera(centerX: 8, centerY: 8, zoom: 1.0)
    let beforeCol = session.world.camera.centerX
    let beforeRow = session.world.camera.centerY

    session.handlePanDelta(deltaX: 64, deltaY: 0)

    // Drag-canvas semantics: drag right → camera col DECREASES, row
    // INCREASES, world content visually shifts RIGHT under the finger.
    #expect(session.world.camera.centerX < beforeCol, "right drag must decrease centerCol")
    #expect(session.world.camera.centerY > beforeRow, "right drag must increase centerRow")
    let dxCol = session.world.camera.centerX - beforeCol
    let dyRow = session.world.camera.centerY - beforeRow
    #expect(abs(dxCol + dyRow) < 0.0001, "horizontal drag is anti-symmetric: dCol == -dRow")
}

@MainActor
@Test("session: drag down moves world down under the finger")
func sessionDragDownMovesWorld() {
    let session = GameSession(
        world: World.fixtureWithTerrain(width: 16, height: 16, fill: .grass, seed: 1)
    )
    session.world.camera = Camera(centerX: 8, centerY: 8, zoom: 1.0)
    let beforeCol = session.world.camera.centerX
    let beforeRow = session.world.camera.centerY

    session.handlePanDelta(deltaX: 0, deltaY: 32)

    // Drag-canvas semantics: drag down → both col and row DECREASE
    // equally. Camera moves UP in scene, world shifts DOWN under finger.
    #expect(session.world.camera.centerX < beforeCol, "down drag must decrease centerCol")
    #expect(session.world.camera.centerY < beforeRow, "down drag must decrease centerRow")
}

@MainActor
@Test("session: pointer up-right moves world up-right (scrolls down-left)")
func sessionPointerUpRightFollows() {
    let session = GameSession(
        world: World.fixtureWithTerrain(width: 16, height: 16, fill: .grass, seed: 1)
    )
    session.world.camera = Camera(centerX: 8, centerY: 8, zoom: 1.0)
    let beforeCol = session.world.camera.centerX
    let beforeRow = session.world.camera.centerY

    // Mouse moves to upper right: dx > 0, dy < 0 (y-down-positive).
    session.handlePanDelta(deltaX: 64, deltaY: -32)

    // Drag-canvas: world content follows the pointer to upper-right,
    // which means the camera (the eye) moves down-left through the
    // world. In iso tile coords: centerCol could go either way, but
    // centerRow definitely INCREASES (camera moves to higher rows,
    // visually down-and-right in iso).
    let dxCol = session.world.camera.centerX - beforeCol
    let dyRow = session.world.camera.centerY - beforeRow
    // Pointer to upper-right is the iso-pure "row" axis: row should
    // increase strongly, col barely move.
    #expect(dyRow > 0, "upper-right pointer must increase centerRow")
    _ = dxCol
}

@MainActor
@Test("session: pinch scales camera zoom and clamps to bounds")
func sessionPinchScalesZoom() {
    let session = GameSession(
        world: World.fixtureWithTerrain(width: 4, height: 4, fill: .grass, seed: 1)
    )
    session.world.camera.setZoom(1.0)
    session.handlePinch(factor: 2.0)
    #expect(session.world.camera.zoom == 2.0)

    // Excessive pinch-out clamps to max.
    session.handlePinch(factor: 100.0)
    #expect(session.world.camera.zoom == Camera.maxZoom)

    // Excessive pinch-in clamps to min.
    session.handlePinch(factor: 0.0001)
    #expect(session.world.camera.zoom == Camera.minZoom)
}

@MainActor
@Test("session: tap selects tile and populates inspector")
func sessionTapSelectsTileAndPopulatesInspector() {
    let session = GameSession(
        world: World.fixtureWithTerrain(width: 6, height: 6, fill: .grass, seed: 1)
    )
    let anchor = TileCoordinate(x: 1, y: 1)
    session.world.enqueue(.place(.house, at: anchor))
    session.world.tick()

    // Tap on the anchor tile.
    session.handleTap(at: anchor)

    let inspector = session.inspector
    #expect(!inspector.bullets.isEmpty, "tap on a placed building must populate the inspector")
    #expect(inspector.bullets.contains(where: { $0.contains("house") }))
}

@MainActor
@Test("session: tap on empty tile produces empty inspector")
func sessionTapOnEmptyTileEmptiesInspector() {
    let session = GameSession(
        world: World.fixtureWithTerrain(width: 6, height: 6, fill: .grass, seed: 1)
    )
    session.handleTap(at: TileCoordinate(x: 2, y: 2))
    #expect(session.inspector.bullets.isEmpty)
}
