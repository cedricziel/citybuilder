import CoreGraphics
import Testing
@testable import CityCore
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
@Test("session: tap with .inspect tool selects tile and populates inspector")
func sessionTapInspectMode() {
    let session = GameSession(
        world: World.fixtureWithTerrain(width: 6, height: 6, fill: .grass, seed: 1)
    )
    let anchor = TileCoordinate(x: 1, y: 1)
    session.world.enqueue(.place(.house, at: anchor))
    session.world.tick()

    #expect(session.selectedTool == .inspect, "fresh session defaults to inspect")
    session.handleTap(at: anchor)

    let inspector = session.inspector
    #expect(!inspector.bullets.isEmpty, "tap on a placed building must populate the inspector")
    #expect(inspector.bullets.contains(where: { $0.contains("house") }))
}

@MainActor
@Test("session: arming a build tool routes tap to .place command")
func sessionTapWithPlaceTool() {
    let session = GameSession(
        world: World.fixtureWithTerrain(width: 6, height: 6, fill: .grass, seed: 1)
    )
    session.selectTool(.place(.road))
    #expect(session.selectedTool == .place(.road))

    let target = TileCoordinate(x: 3, y: 3)
    session.handleTap(at: target)
    session.world.tick()

    #expect(session.world.occupiedTiles[target] != nil, "tap with road tool must place a road")
    #expect(session.selectedTool == .place(.road), "tool stays armed after a placement")
}

@MainActor
@Test("session: tapping the armed tool again disarms it")
func sessionToolToggle() {
    let session = GameSession(
        world: World.fixtureWithTerrain(width: 6, height: 6, fill: .grass, seed: 1)
    )
    session.selectTool(.place(.house))
    session.selectTool(.place(.house))
    #expect(session.selectedTool == .inspect, "tapping the armed tool again returns to inspect")
}

@MainActor
@Test("session: demolish tool routes tap to .demolish command")
func sessionTapWithDemolishTool() {
    let session = GameSession(
        world: World.fixtureWithTerrain(width: 6, height: 6, fill: .grass, seed: 1)
    )
    let anchor = TileCoordinate(x: 1, y: 1)
    session.world.enqueue(.place(.house, at: anchor))
    session.world.tick()
    #expect(session.world.occupiedTiles[anchor] != nil)

    session.selectTool(.demolish)
    session.handleTap(at: anchor)
    session.world.tick()
    #expect(session.world.occupiedTiles[anchor] == nil, "demolish tool removes the building on tap")
}

@MainActor
@Test("session: drag-paint with road tool places road on every entered tile")
func sessionDragPaintsRoads() {
    let session = GameSession(
        world: World.fixtureWithTerrain(width: 8, height: 8, fill: .grass, seed: 1)
    )
    session.selectTool(.place(.road))

    let tiles = [
        TileCoordinate(x: 1, y: 3),
        TileCoordinate(x: 2, y: 3),
        TileCoordinate(x: 3, y: 3),
        TileCoordinate(x: 4, y: 3)
    ]
    for tile in tiles {
        session.handleDrag(at: tile)
    }
    session.world.tick()
    for tile in tiles {
        #expect(session.world.occupiedTiles[tile] != nil, "road must land on every dragged tile")
    }
}

@MainActor
@Test("session: drag in inspect mode is a no-op")
func sessionDragIgnoredInInspectMode() {
    let session = GameSession(
        world: World.fixtureWithTerrain(width: 8, height: 8, fill: .grass, seed: 1)
    )
    #expect(session.selectedTool == .inspect)
    session.handleDrag(at: TileCoordinate(x: 4, y: 4))
    session.world.tick()
    #expect(session.world.occupiedTiles[TileCoordinate(x: 4, y: 4)] == nil)
}

@MainActor
@Test("session: ghost state reflects armed tool + hovered tile + canPlace")
func sessionGhostStateReflectsValidity() {
    let session = GameSession(
        world: World.fixtureWithTerrain(width: 8, height: 8, fill: .grass, seed: 1)
    )
    // No hover yet → no ghost.
    #expect(session.ghostState() == nil)

    // Inspect mode never shows ghost even when hovering.
    session.handleHover(at: TileCoordinate(x: 4, y: 4))
    #expect(session.ghostState() == nil)

    // Arm a place tool → ghost appears at the hovered tile.
    session.selectTool(.place(.house))
    let ghost = session.ghostState()
    #expect(ghost?.kind == .house)
    #expect(ghost?.tile == TileCoordinate(x: 4, y: 4))
    #expect(ghost?.valid == true, "grass + sufficient funds → valid")

    // Out-of-bounds hover → invalid (canPlace rejects out-of-bounds).
    session.handleHover(at: TileCoordinate(x: 99, y: 99))
    #expect(session.ghostState()?.valid == false)
}

@MainActor
@Test("session: ghost state is invalid when player can't afford the building")
func sessionGhostStateInvalidWhenBroke() {
    var world = World.fixtureWithTerrain(width: 8, height: 8, fill: .grass, seed: 1)
    world.economy.balance = 0
    let session = GameSession(world: world)
    session.selectTool(.place(.house))
    session.handleHover(at: TileCoordinate(x: 4, y: 4))
    #expect(session.ghostState()?.valid == false, "broke + valid tile → ghost shows invalid")
}

@MainActor
@Test("session: armed tool cost reads from BuildingCatalog")
func sessionArmedToolCost() {
    let session = GameSession(
        world: World.fixtureWithTerrain(width: 4, height: 4, fill: .grass, seed: 1)
    )
    #expect(session.armedToolCost == 0, "inspect tool has no cost")
    session.selectTool(.place(.road))
    #expect(session.armedToolCost == BuildingCatalog.spec(for: .road).cost)
    session.selectTool(.place(.house))
    #expect(session.armedToolCost == BuildingCatalog.spec(for: .house).cost)
    session.selectTool(.demolish)
    #expect(session.armedToolCost == 0, "demolish has no cost surfaced (refund logic is M5)")
}
