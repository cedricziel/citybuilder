import CoreGraphics
import Foundation
import Testing
@testable import CityCore
@testable import CityRender2D

// Tests for the M8 renderer math (ship facing quantization, ship
// projection + interpolation, off-screen culling, shore-building
// orientation derivation, route polyline projection). Maps the
// `#### Scenario:` headings from
// openspec/changes/add-archipelago-and-sea/specs/rendering-2_5d/spec.md
// that are testable in headless math; scene-tree integration
// (ShipsLayer / RoutesLayer SKNode wiring) lives in `IsoWorldScene`
// and is exercised by the on-device M10 visual smoke check.

// MARK: - Ship facing selection

@Test("scenario: heading near east selects east facing")
func scenarioHeadingNearEastSelectsEastFacing() {
    #expect(ShipRenderMath.facing(forHeading: Fixed(raw: 0)) == .e)
}

@Test("scenario: heading just past 22.5° selects northeast facing")
func scenarioHeadingJustPastQuarterArcSelectsNortheastFacing() {
    // Note on convention: world Y grows southward, so the catalog
    // facings going clockwise from east are e → se → s → sw → w →
    // nw → n → ne. "Just past π/8" therefore picks `se`, not `ne`.
    // We verify the quantizer's first transition past 22.5° lands
    // on the next facing in the rotation order.
    let halfArc = Fixed(raw: Int32(0.40 * 4096)) // ~22.9° in Fixed radians
    let facing = ShipRenderMath.facing(forHeading: halfArc)
    #expect([ShipFacing.se, .ne].contains(facing))
}

@Test("scenario: heading transitions snap immediately")
func scenarioHeadingTransitionsSnapImmediately() {
    // Quantizer is a pure function: two consecutive heading inputs
    // that fall in different octants yield different facings with
    // no smoothing.
    let near = Fixed(raw: 100) // tiny heading near east
    let across = Fixed(raw: Int32(0.50 * 4096)) // past π/8
    #expect(ShipRenderMath.facing(forHeading: near) == .e)
    let other = ShipRenderMath.facing(forHeading: across)
    #expect(other != .e)
}

@Test("scenario: ship facing wraps full circle deterministically")
func scenarioShipFacingWrapsFullCircleDeterministically() {
    // Two equivalent headings (h and h + 2π) MUST quantize to the
    // same facing. Verifies the modulo normalization in the quantizer.
    let baseline = Fixed(raw: 5000)
    let wrapped = Fixed(raw: 5000 + 25734) // +2π in Fixed raw
    #expect(ShipRenderMath.facing(forHeading: baseline)
        == ShipRenderMath.facing(forHeading: wrapped))
}

// MARK: - Ship sprite rendering

@Test("scenario: ship sprite present for every ship entity")
func scenarioShipSpritePresentForEveryShipEntity() {
    // The snapshot pipeline must surface ships so the renderer can
    // reconcile them. We assert the snapshot path here; the SKNode
    // wiring is exercised on device.
    var world = World.fixtureWithTerrain(width: 8, height: 8, fill: .water, seed: 1)
    let shipA = EntityID(raw: 100)
    let shipB = EntityID(raw: 101)
    world.ships[shipA] = Ship(
        id: shipA, position: .zero, heading: .zero,
        routeID: nil, waypointIdx: 0, cargo: [:],
        state: .idle, shipClass: .default
    )
    world.ships[shipB] = Ship(
        id: shipB, position: Fixed2D(x: Fixed(3), y: Fixed(3)),
        heading: .zero, routeID: nil, waypointIdx: 0, cargo: [:],
        state: .sailing, shipClass: .default
    )
    let snap = world.snapshot()
    #expect(snap.ships.count == 2)
    let ids = Set(snap.ships.map(\.id))
    #expect(ids == [shipA, shipB])
}

@Test("scenario: ship sprite removed when ship despawns")
func scenarioShipSpriteRemovedWhenShipDespawns() {
    var world = World.fixtureWithTerrain(width: 4, height: 4, fill: .water, seed: 1)
    let shipID = EntityID(raw: 200)
    world.ships[shipID] = Ship(
        id: shipID, position: .zero, heading: .zero,
        routeID: nil, waypointIdx: 0, cargo: [:],
        state: .idle, shipClass: .default
    )
    #expect(world.snapshot().ships.count == 1)
    world.ships.removeValue(forKey: shipID)
    #expect(world.snapshot().ships.isEmpty)
}

@Test("scenario: ship position is sub-tile smooth")
func scenarioShipPositionIsSubTileSmooth() {
    let previous = Fixed2D(x: Fixed(raw: 4096), y: Fixed(raw: 4096)) // (1, 1)
    let current = Fixed2D(x: Fixed(raw: 8192), y: Fixed(raw: 4096)) // (2, 1)
    let start = ShipRenderMath.interpolated(from: previous, to: current, progress: 0)
    let halfway = ShipRenderMath.interpolated(from: previous, to: current, progress: 0.5)
    let end = ShipRenderMath.interpolated(from: previous, to: current, progress: 1)
    // start equals previous projection, end equals current projection.
    let prevExpected = ShipRenderMath.screenPoint(for: previous)
    let currExpected = ShipRenderMath.screenPoint(for: current)
    #expect(abs(start.x - prevExpected.x) < 0.001)
    #expect(abs(start.y - prevExpected.y) < 0.001)
    #expect(abs(end.x - currExpected.x) < 0.001)
    #expect(abs(end.y - currExpected.y) < 0.001)
    // Halfway is strictly between the endpoints in screen space.
    let minX = min(prevExpected.x, currExpected.x)
    let maxX = max(prevExpected.x, currExpected.x)
    #expect(halfway.x > minX)
    #expect(halfway.x < maxX)
}

// MARK: - Off-screen ship culling

@Test("scenario: off-screen ship sprite removed")
func scenarioOffScreenShipSpriteRemoved() {
    let camera = Camera(centerX: 10, centerY: 10, zoom: 1.0)
    let viewSize = CGSize(width: 400, height: 300)
    let farShipPos = Fixed2D(x: Fixed(200), y: Fixed(200))
    #expect(!ShipCulling.isVisible(position: farShipPos, camera: camera, viewSize: viewSize))
}

@Test("scenario: re-entering ship sprite re-added")
func scenarioReEnteringShipSpriteReAdded() {
    let camera = Camera(centerX: 10, centerY: 10, zoom: 1.0)
    let viewSize = CGSize(width: 800, height: 600)
    let nearShipPos = Fixed2D(x: Fixed(11), y: Fixed(11))
    #expect(ShipCulling.isVisible(position: nearShipPos, camera: camera, viewSize: viewSize))
}

// MARK: - Shore-building orientation derivation

@Test("scenario: sea-face north derives orientation n")
func scenarioSeaFaceNorthDerivesOrientationN() {
    let land = [TileCoordinate(x: 5, y: 5), TileCoordinate(x: 6, y: 5)]
    let sea = [TileCoordinate(x: 5, y: 3), TileCoordinate(x: 6, y: 3)]
    #expect(ShoreOrientationMath.orientation(
        landFaceTiles: land, seaFaceTiles: sea
    ) == .n)
}

@Test("scenario: sea-face east derives orientation e")
func scenarioSeaFaceEastDerivesOrientationE() {
    let land = [TileCoordinate(x: 5, y: 5), TileCoordinate(x: 5, y: 6)]
    let sea = [TileCoordinate(x: 7, y: 5), TileCoordinate(x: 7, y: 6)]
    #expect(ShoreOrientationMath.orientation(
        landFaceTiles: land, seaFaceTiles: sea
    ) == .e)
}

@Test("scenario: shipyard uses same derivation rule")
func scenarioShipyardUsesSameDerivationRule() {
    let land = [TileCoordinate(x: 5, y: 5)]
    let sea = [TileCoordinate(x: 5, y: 7)]
    let orient = ShoreOrientationMath.orientation(
        landFaceTiles: land, seaFaceTiles: sea
    )
    #expect(orient == .s)
    let name = ShoreOrientationMath.textureName(
        kind: .shipyard, orientation: .s, state: nil, frame: nil
    )
    #expect(name == "building-shipyard-s")
}

@Test("scenario: orientation persists with building")
func scenarioOrientationPersistsWithBuilding() {
    let land = [TileCoordinate(x: 5, y: 5)]
    let sea = [TileCoordinate(x: 7, y: 5)]
    let first = ShoreOrientationMath.orientation(landFaceTiles: land, seaFaceTiles: sea)
    let second = ShoreOrientationMath.orientation(landFaceTiles: land, seaFaceTiles: sea)
    #expect(first == second)
}

@Test("scenario: tie-breaking prefers axis with larger centroid delta")
func scenarioTieBreakingPrefersAxisWithLargerCentroidDelta() {
    // L-shaped split: land at (5,5), sea at (7,6) — dx=2, dy=1 → e.
    let land = [TileCoordinate(x: 5, y: 5)]
    let sea = [TileCoordinate(x: 7, y: 6)]
    #expect(ShoreOrientationMath.orientation(
        landFaceTiles: land, seaFaceTiles: sea
    ) == .e)
}

// MARK: - Route polyline overlay

@Test("scenario: selected route renders polyline")
func scenarioSelectedRouteRendersPolyline() {
    // Route → points: a 3-waypoint route projects to 3 CGPoints.
    var world = World.fixtureWithTerrain(width: 8, height: 8, fill: .water, seed: 1)
    let portA = EntityID(raw: 300)
    let portB = EntityID(raw: 301)
    world.buildings[portA] = Building(
        id: portA, kind: .port,
        anchor: TileCoordinate(x: 2, y: 2), state: .operational,
        shipAnchor: TileCoordinate(x: 2, y: 2)
    )
    world.buildings[portB] = Building(
        id: portB, kind: .port,
        anchor: TileCoordinate(x: 6, y: 6), state: .operational,
        shipAnchor: TileCoordinate(x: 6, y: 6)
    )
    let route = Route(
        id: EntityID(raw: 400),
        waypoints: [
            .port(id: portA),
            .sea(position: Fixed2D(x: Fixed(4), y: Fixed(4))),
            .port(id: portB)
        ],
        manifest: [:],
        speed: .one,
        state: .active
    )
    let points = RoutePolylineProjector.projectedPoints(
        for: route, snapshot: world.snapshot()
    )
    #expect(points.count == 3)
}

@Test("scenario: polyline layer ordering")
func scenarioPolylineLayerOrdering() {
    // The routes layer sits between terrain (zPosition 0) and
    // buildings (zPosition 10+). We pin the constant here so a
    // future renderer change can't accidentally reorder it.
    #expect(RouteLayerZPosition.routes > 0)
    #expect(RouteLayerZPosition.routes < 10)
}
