import CoreGraphics
import Foundation
import Testing
@testable import CityCore
@testable import CityRender2D

// Tests for spec rendering-2_5d (M2 scope). Each `#### Scenario:` heading
// maps to one `@Test("scenario: <lowercased title>")` here. The "frame
// budget held under load" scenario is a perf gate handled in M11.

// MARK: - Iso projection (variable footprint)

@Test("scenario: variable-footprint building drawn correctly")
func scenarioVariableFootprintBuildingDrawnCorrectly() {
    // A 3×3 building anchored at tile (10, 10) renders as a single visual
    // unit at the iso projection of (10, 10) — the renderer offsets its
    // sprite by the footprint when drawing, but the anchor is the
    // single-tile projection.
    let anchor = TileCoordinate(x: 10, y: 10)
    let projected = IsoMath.screenPoint(forTile: anchor)

    // The fractional projection through (10.0, 10.0) MUST equal the integer
    // projection of (10, 10). This is the invariant that lets the renderer
    // align building art identically regardless of footprint size.
    let fractional = IsoMath.screenPoint(forTileFractionalX: 10.0, fractionalY: 10.0)
    #expect(projected == fractional)
}

// MARK: - Snapshot-driven rendering

@Test("scenario: shore building sprite carries its cardinal orientation")
func scenarioShoreBuildingSpriteCarriesItsCardinalOrientation() {
    // Regression test for the magenta-port bug: a shore building placed
    // with sea tiles to the east of the land tiles MUST surface through
    // the reconciler's SpriteSpec with `orientation: .e` so the renderer
    // looks up `building-port-e` rather than the non-existent
    // `building-port`. Non-shore buildings on the same snapshot MUST
    // continue to carry `orientation: nil`.
    var world = World.fixtureWithTerrain(width: 8, height: 8, fill: .grass, seed: 1)
    // Make the right-hand column water so a 2x1-ish shore footprint at
    // x=3 sits with land to the west and water to the east.
    for tileY in 0 ..< 8 {
        world.terrainGrid[tileY * 8 + 4] = .water
    }
    world.camera = Camera(centerX: 4, centerY: 4, zoom: 1.0)
    let portId = EntityID(raw: 7)
    let port = Building(
        id: portId,
        kind: .port,
        anchor: TileCoordinate(x: 3, y: 3),
        state: .operational,
        landFaceTiles: [TileCoordinate(x: 3, y: 3)],
        seaFaceTiles: [TileCoordinate(x: 4, y: 3)]
    )
    world.buildings[portId] = port
    world.occupiedTiles[TileCoordinate(x: 3, y: 3)] = portId
    let houseId = EntityID(raw: 8)
    world.buildings[houseId] = Building(
        id: houseId,
        kind: .house,
        anchor: TileCoordinate(x: 1, y: 1),
        state: .operational
    )
    world.occupiedTiles[TileCoordinate(x: 1, y: 1)] = houseId

    let snap = world.snapshot()
    let desired = SnapshotReconciler.desiredSprites(
        in: snap,
        xRange: 0 ... 7,
        yRange: 0 ... 7
    )

    var portOrientation: ShoreOrientation??
    var houseOrientation: ShoreOrientation??
    for spec in desired {
        if case let .building(kind, _, _, _, orientation, _, _, _) = spec.kind {
            if kind == .port { portOrientation = orientation }
            if kind == .house { houseOrientation = orientation }
        }
    }
    #expect(
        portOrientation == .some(.some(.e)),
        "port with sea tiles east of land must orient east; got \(String(describing: portOrientation))"
    )
    #expect(houseOrientation == .some(.none), "non-shore building must carry nil orientation")
}

@Test("scenario: snapshot-driven rendering")
func scenarioSnapshotDrivenRendering() {
    var world = World.fixtureWithTerrain(width: 4, height: 4, fill: .grass, seed: 1)
    world.camera = Camera(centerX: 2, centerY: 2, zoom: 1.0)
    let snap = world.snapshot()
    let viewSize = CGSize(width: 800, height: 600)
    guard let (xRange, yRange) = Culling.visibleTileRange(
        camera: snap.camera,
        viewSize: viewSize,
        mapWidth: snap.mapWidth,
        mapHeight: snap.mapHeight
    )
    else {
        Issue.record("expected a visible range for a fully-on-screen 4×4 map")
        return
    }
    let desired = SnapshotReconciler.desiredSprites(in: snap, xRange: xRange, yRange: yRange)
    // 16 grass tiles, no buildings yet.
    let terrainCount = desired.count(where: { if case .terrain = $0.kind { true } else { false } })
    let buildingCount = desired.count(where: { if case .building = $0.kind { true } else { false } })
    #expect(terrainCount == 16)
    #expect(buildingCount == 0)
}

// MARK: - Culling

@Test("scenario: off-screen tile not in scene")
func scenarioOffScreenTileNotInScene() {
    // Camera centered at the top-left. A tile at the bottom-right of a
    // large map MUST not appear in the visible range plus margin.
    var world = World.fixtureWithTerrain(width: 200, height: 200, fill: .grass, seed: 1)
    world.camera = Camera(centerX: 10, centerY: 10, zoom: 1.0)
    let snap = world.snapshot()
    let viewSize = CGSize(width: 400, height: 400)
    let farTile = TileCoordinate(x: 190, y: 190)
    let visible = Culling.isVisible(
        farTile,
        camera: snap.camera,
        viewSize: viewSize,
        mapWidth: snap.mapWidth,
        mapHeight: snap.mapHeight
    )
    #expect(!visible)

    // Cross-check: a tile near the camera center MUST be visible.
    let nearTile = TileCoordinate(x: 10, y: 10)
    let nearVisible = Culling.isVisible(
        nearTile,
        camera: snap.camera,
        viewSize: viewSize,
        mapWidth: snap.mapWidth,
        mapHeight: snap.mapHeight
    )
    #expect(nearVisible)
}

// MARK: - Pan / pinch / zoom

@Test("scenario: two-finger pan")
func scenarioTwoFingerPan() {
    // "World follows finger" is the load-bearing invariant. We assert it
    // directly: take the tile the finger was over before the drag, apply
    // the pan to the camera, and check that the same tile is now under
    // the new finger position. Anything else (raw deltas, iso math
    // internals) can change without breaking the test.
    let camera = Camera(centerX: 10, centerY: 10, zoom: 1.0)
    let fingerStart = CGPoint(x: 0, y: 0)
    let screenDelta = CGSize(width: 64, height: 32)
    let fingerEnd = CGPoint(x: fingerStart.x + screenDelta.width, y: fingerStart.y + screenDelta.height)

    // Sample which world tile sits under the finger at the start, in
    // camera-relative scene space.
    let startSceneY = -fingerStart.y // SwiftUI down-positive → scene y-up
    let startPoint = CGPoint(
        x: fingerStart.x + CGFloat(camera.centerX - camera.centerY) * (IsoMath.tileWidth / 2),
        y: startSceneY - CGFloat(camera.centerX + camera.centerY) * (IsoMath.tileHeight / 2)
    )
    let tileUnderStart = IsoMath.nearestTile(toScreenPoint: startPoint)

    // Apply the pan intent.
    let intent = InputTranslator.panIntent(screenDelta: screenDelta, camera: camera)
    guard case let .panCamera(deltaX, deltaY) = intent else {
        Issue.record("expected panCamera intent")
        return
    }
    var moved = camera
    moved.pan(deltaX: deltaX, deltaY: deltaY)

    // Sample which world tile sits under the finger at the end (in the
    // moved camera's frame).
    let endSceneY = -fingerEnd.y
    let endPoint = CGPoint(
        x: fingerEnd.x + CGFloat(moved.centerX - moved.centerY) * (IsoMath.tileWidth / 2),
        y: endSceneY - CGFloat(moved.centerX + moved.centerY) * (IsoMath.tileHeight / 2)
    )
    let tileUnderEnd = IsoMath.nearestTile(toScreenPoint: endPoint)

    #expect(tileUnderEnd == tileUnderStart, "world tile under the finger must not change during a drag")
}

@Test("pan direction: drag right shifts camera so world follows")
func panDragRightMovesWorldRight() {
    let camera = Camera(centerX: 10, centerY: 10, zoom: 1.0)
    guard case let .panCamera(dCol, dRow) = InputTranslator.panIntent(
        screenDelta: CGSize(width: 64, height: 0),
        camera: camera
    )
    else {
        Issue.record("expected panCamera intent")
        return
    }
    // Pure horizontal drag-right: camera col decreases, row increases, equal
    // magnitude. Net effect: camera screen-x moves LEFT, world content
    // shifts RIGHT under the finger.
    #expect(dCol < 0, "right drag must decrease centerCol")
    #expect(dRow > 0, "right drag must increase centerRow")
    #expect(abs(dCol + dRow) < 0.0001, "horizontal drag is anti-symmetric: dCol == -dRow")
}

@Test("pan direction: drag down shifts camera so world follows")
func panDragDownMovesWorldDown() {
    let camera = Camera(centerX: 10, centerY: 10, zoom: 1.0)
    guard case let .panCamera(dCol, dRow) = InputTranslator.panIntent(
        screenDelta: CGSize(width: 0, height: 32),
        camera: camera
    )
    else {
        Issue.record("expected panCamera intent")
        return
    }
    // Pure vertical drag-down: both col and row DECREASE equally. Camera
    // scene-y INCREASES (less negative), camera moves UP in scene, world
    // content shifts DOWN with the finger.
    #expect(dCol < 0, "down drag must decrease centerCol")
    #expect(dRow < 0, "down drag must decrease centerRow")
    #expect(abs(dCol - dRow) < 0.0001, "vertical drag is symmetric along the iso diagonal: dCol == dRow")
}

@Test("pan direction: drag up scrolls content down")
func panDragUpMovesWorldUp() {
    let camera = Camera(centerX: 10, centerY: 10, zoom: 1.0)
    guard case let .panCamera(dCol, dRow) = InputTranslator.panIntent(
        screenDelta: CGSize(width: 0, height: -32),
        camera: camera
    )
    else {
        Issue.record("expected panCamera intent")
        return
    }
    // Drag-up is symmetric to drag-down: both col and row INCREASE so the
    // camera moves DOWN in scene and the world content shifts UP — which
    // looks like "scroll down" in scrollbar terms.
    #expect(dCol > 0)
    #expect(dRow > 0)
}

@Test("pan zoom: deltas scale inversely with zoom")
func panZoomScalesDeltas() {
    let cam1 = Camera(centerX: 10, centerY: 10, zoom: 1.0)
    let cam2 = Camera(centerX: 10, centerY: 10, zoom: 2.0)
    guard case let .panCamera(dx1, _) = InputTranslator.panIntent(screenDelta: CGSize(width: 64, height: 0), camera: cam1),
          case let .panCamera(dx2, _) = InputTranslator.panIntent(screenDelta: CGSize(width: 64, height: 0), camera: cam2)
    else {
        Issue.record("expected panCamera intents")
        return
    }
    // At 2x zoom, the same screen drag covers half as many tiles.
    #expect(abs(abs(dx2) * 2 - abs(dx1)) < 0.0001)
}

@Test("scenario: pinch zoom respects bounds")
func scenarioPinchZoomRespectsBounds() {
    var camera = Camera(centerX: 0, centerY: 0, zoom: 1.0)
    // Pinch inward beyond min.
    camera.multiplyZoom(by: 0.01)
    #expect(camera.zoom == Camera.minZoom, "zoom must clamp to minZoom on excessive pinch-in")

    // Pinch outward beyond max.
    camera.setZoom(100.0)
    #expect(camera.zoom == Camera.maxZoom, "zoom must clamp to maxZoom on excessive pinch-out")
}

@Test("scenario: camera persists across save/load")
func scenarioCameraPersistsAcrossSaveLoad() throws {
    var world = World.fixtureWithTerrain(width: 8, height: 8, fill: .grass, seed: 42)
    world.camera = Camera(centerX: 3.5, centerY: 5.25, zoom: 1.75)

    let encoded = try JSONEncoder().encode(world)
    let decoded = try JSONDecoder().decode(World.self, from: encoded)
    #expect(decoded.camera == world.camera)
}

// MARK: - Tap intent

@Test("scenario: tap dispatched as intent")
func scenarioTapDispatchedAsIntent() {
    // Tap at the iso projection of tile (5, 7) MUST round-trip to a
    // tapTile(5, 7) intent.
    let target = TileCoordinate(x: 5, y: 7)
    let point = IsoMath.screenPoint(forTile: target)
    let intent = InputTranslator.tapIntent(
        atScreenPoint: point,
        mapWidth: 96,
        mapHeight: 96
    )
    #expect(intent == .tapTile(target))
}

// MARK: - Performance budget (M11)

@Test("scenario: frame budget held under load")
func scenarioFrameBudgetHeldUnderLoad() {
    // Real perf verification happens on hardware in M11 task 11.3. As a
    // headless stand-in we assert the math budget: at zoom 1, a 96×96
    // map produces no more than a manageable sprite count after culling
    // with a reasonable view size. The sprite count cap protects against
    // accidental reconciliation blow-ups that would tank the frame rate.
    var world = World.fixtureWithTerrain(width: 96, height: 96, fill: .grass, seed: 1)
    world.camera = Camera(centerX: 48, centerY: 48, zoom: 1.0)
    let snap = world.snapshot()
    if let (xRange, yRange) = Culling.visibleTileRange(
        camera: snap.camera,
        viewSize: CGSize(width: 1024, height: 768),
        mapWidth: snap.mapWidth,
        mapHeight: snap.mapHeight
    ) {
        let spriteCount = (xRange.count) * (yRange.count)
        #expect(spriteCount < 5000, "culling keeps visible sprite count under 5000 → 60 fps achievable")
    }
}

// MARK: - Frame interpolation

@Test("scenario: carrier moves smoothly between ticks")
func scenarioCarrierMovesSmoothlyBetweenTicks() {
    let previous = (col: 4.0, row: 6.0)
    let current = (col: 5.0, row: 6.0)
    let halfway = FrameInterpolation.interpolatedTilePosition(from: previous, to: current, at: 0.5)
    #expect(abs(halfway.col - 4.5) < 0.0001)
    #expect(abs(halfway.row - 6.0) < 0.0001)

    let start = FrameInterpolation.interpolatedTilePosition(from: previous, to: current, at: 0.0)
    let end = FrameInterpolation.interpolatedTilePosition(from: previous, to: current, at: 1.0)
    #expect(start.col == previous.col)
    #expect(end.col == current.col)
}
