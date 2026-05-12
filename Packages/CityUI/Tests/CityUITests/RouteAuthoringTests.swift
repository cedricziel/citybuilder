import Foundation
import Testing
@testable import CityCore
@testable import CityUI

// Tests for the M9 route-authoring view-model. Each `#### Scenario:`
// under `Requirement: Route-authoring input mode` in
// openspec/changes/add-archipelago-and-sea/specs/rendering-2_5d/spec.md
// maps to one `@Test` here.

private struct ShoreFixture {
    let snapshot: WorldSnapshot
    let portA: EntityID
    let portB: EntityID
}

@MainActor
private func makeShoreSnapshot() -> ShoreFixture {
    var world = World.fixtureWithTerrain(width: 12, height: 6, fill: .water, seed: 1)
    // Two grass tiles on opposite ends of the map; ship anchors sit
    // one tile south so the route between them stays on open water.
    world.terrainGrid[1 * world.mapWidth + 1] = .grass
    world.terrainGrid[1 * world.mapWidth + 10] = .grass
    let portA = EntityID(raw: 500)
    let portB = EntityID(raw: 501)
    world.buildings[portA] = Building(
        id: portA, kind: .port,
        anchor: TileCoordinate(x: 1, y: 1), state: .operational,
        landFaceTiles: [TileCoordinate(x: 1, y: 1)],
        seaFaceTiles: [TileCoordinate(x: 1, y: 2)],
        shipAnchor: TileCoordinate(x: 1, y: 2)
    )
    world.buildings[portB] = Building(
        id: portB, kind: .port,
        anchor: TileCoordinate(x: 10, y: 1), state: .operational,
        landFaceTiles: [TileCoordinate(x: 10, y: 1)],
        seaFaceTiles: [TileCoordinate(x: 10, y: 2)],
        shipAnchor: TileCoordinate(x: 10, y: 2)
    )
    return ShoreFixture(snapshot: world.snapshot(), portA: portA, portB: portB)
}

@MainActor
private func makeViewModel(
    snapshot: WorldSnapshot, sink: ((Command) -> Void)? = nil
) -> (RouteAuthoringViewModel, () -> [Command]) {
    var captured: [Command] = []
    let viewModel = RouteAuthoringViewModel(commandSink: { command in
        if let sink {
            sink(command)
        } else {
            captured.append(command)
        }
    })
    viewModel.snapshot = snapshot
    return (viewModel, { captured })
}

// MARK: - Tap routing

@Test("scenario: tap on port adds port waypoint")
@MainActor
func scenarioTapOnPortAddsPortWaypoint() {
    let fixture = makeShoreSnapshot(); let snap = fixture.snapshot; let portA = fixture.portA
    let (viewModel, _) = makeViewModel(snapshot: snap)
    viewModel.tapHandler(target: .port(id: portA))
    #expect(viewModel.inProgressWaypoints.count == 1)
    if case let .port(id) = viewModel.inProgressWaypoints[0] {
        #expect(id == portA)
    } else {
        Issue.record("expected .port waypoint")
    }
}

@Test("scenario: tap on water tile adds sea waypoint")
@MainActor
func scenarioTapOnWaterTileAddsSeaWaypoint() {
    let snap = makeShoreSnapshot().snapshot
    let (viewModel, _) = makeViewModel(snapshot: snap)
    let waterTile = TileCoordinate(x: 5, y: 5)
    viewModel.tapHandler(target: .water(tile: waterTile))
    #expect(viewModel.inProgressWaypoints.count == 1)
    if case let .sea(pos) = viewModel.inProgressWaypoints[0] {
        #expect(pos.x.raw == Int32(waterTile.x) * Fixed.scale)
        #expect(pos.y.raw == Int32(waterTile.y) * Fixed.scale)
    } else {
        Issue.record("expected .sea waypoint")
    }
}

@Test("scenario: tap on land tile rejected")
@MainActor
func scenarioTapOnLandTileRejected() {
    let snap = makeShoreSnapshot().snapshot
    let (viewModel, _) = makeViewModel(snapshot: snap)
    let landTile = TileCoordinate(x: 1, y: 1)
    viewModel.tapHandler(target: .land(tile: landTile))
    #expect(viewModel.inProgressWaypoints.isEmpty)
    let feedback = viewModel.consumeRejectedTapFeedback()
    #expect(feedback?.location == landTile)
    #expect(viewModel.consumeRejectedTapFeedback() == nil)
}

// MARK: - Live validation

@Test("scenario: land-crossing segment highlighted red")
@MainActor
func scenarioLandCrossingSegmentHighlightedRed() {
    var world = World.fixtureWithTerrain(width: 12, height: 4, fill: .water, seed: 1)
    // Vertical wall of grass at x=6 so any segment crossing it
    // touches land.
    for tileY in 0 ..< world.mapHeight {
        world.terrainGrid[tileY * world.mapWidth + 6] = .grass
    }
    // Ports on either side of the wall.
    let portA = EntityID(raw: 600)
    let portB = EntityID(raw: 601)
    world.buildings[portA] = Building(
        id: portA, kind: .port,
        anchor: TileCoordinate(x: 1, y: 1), state: .operational,
        landFaceTiles: [TileCoordinate(x: 1, y: 1)],
        seaFaceTiles: [TileCoordinate(x: 1, y: 2)],
        shipAnchor: TileCoordinate(x: 1, y: 2)
    )
    world.buildings[portB] = Building(
        id: portB, kind: .port,
        anchor: TileCoordinate(x: 10, y: 1), state: .operational,
        landFaceTiles: [TileCoordinate(x: 10, y: 1)],
        seaFaceTiles: [TileCoordinate(x: 10, y: 2)],
        shipAnchor: TileCoordinate(x: 10, y: 2)
    )
    let snap = world.snapshot()
    let (viewModel, _) = makeViewModel(snapshot: snap)
    viewModel.tapHandler(target: .port(id: portA))
    viewModel.tapHandler(target: .port(id: portB))
    #expect(viewModel.redSegments.contains(0))
}

@Test("scenario: clear sea segment is not red")
@MainActor
func scenarioClearSeaSegmentIsNotRed() {
    let fixture = makeShoreSnapshot(); let snap = fixture.snapshot; let portA = fixture.portA; let portB = fixture.portB
    let (viewModel, _) = makeViewModel(snapshot: snap)
    viewModel.tapHandler(target: .port(id: portA))
    viewModel.tapHandler(target: .port(id: portB))
    #expect(viewModel.redSegments.isEmpty)
}

// MARK: - Commit / cancel

@Test("scenario: commit issues createroute command")
@MainActor
func scenarioCommitIssuesCreateRouteCommand() {
    let fixture = makeShoreSnapshot(); let snap = fixture.snapshot; let portA = fixture.portA; let portB = fixture.portB
    let (viewModel, captured) = makeViewModel(snapshot: snap)
    viewModel.tapHandler(target: .port(id: portA))
    viewModel.tapHandler(target: .port(id: portB))
    viewModel.commit()
    let commands = captured()
    #expect(commands.count == 1)
    if case let .createRoute(waypoints, _, _) = commands[0] {
        #expect(waypoints.count == 2)
    } else {
        Issue.record("expected createRoute command")
    }
    #expect(viewModel.inProgressWaypoints.isEmpty)
}

@Test("scenario: commit rejected when red segments remain")
@MainActor
func scenarioCommitRejectedWhenRedSegmentsRemain() {
    var world = World.fixtureWithTerrain(width: 12, height: 4, fill: .water, seed: 1)
    for tileY in 0 ..< world.mapHeight {
        world.terrainGrid[tileY * world.mapWidth + 6] = .grass
    }
    let portA = EntityID(raw: 700)
    let portB = EntityID(raw: 701)
    world.buildings[portA] = Building(
        id: portA, kind: .port,
        anchor: TileCoordinate(x: 1, y: 1), state: .operational,
        landFaceTiles: [TileCoordinate(x: 1, y: 1)],
        seaFaceTiles: [TileCoordinate(x: 1, y: 2)],
        shipAnchor: TileCoordinate(x: 1, y: 2)
    )
    world.buildings[portB] = Building(
        id: portB, kind: .port,
        anchor: TileCoordinate(x: 10, y: 1), state: .operational,
        landFaceTiles: [TileCoordinate(x: 10, y: 1)],
        seaFaceTiles: [TileCoordinate(x: 10, y: 2)],
        shipAnchor: TileCoordinate(x: 10, y: 2)
    )
    let snap = world.snapshot()
    let (viewModel, captured) = makeViewModel(snapshot: snap)
    viewModel.tapHandler(target: .port(id: portA))
    viewModel.tapHandler(target: .port(id: portB))
    viewModel.commit()
    #expect(captured().isEmpty)
    #expect(viewModel.commitRejectionReason == .landCrossingSegment)
    #expect(!viewModel.inProgressWaypoints.isEmpty, "in-progress route must survive a rejected commit")
}

@Test("scenario: commit rejected when fewer than two ports")
@MainActor
func scenarioCommitRejectedWhenFewerThanTwoPorts() {
    let fixture = makeShoreSnapshot(); let snap = fixture.snapshot; let portA = fixture.portA
    let (viewModel, captured) = makeViewModel(snapshot: snap)
    viewModel.tapHandler(target: .port(id: portA))
    viewModel.tapHandler(target: .water(tile: TileCoordinate(x: 5, y: 5)))
    viewModel.commit()
    #expect(captured().isEmpty)
    #expect(viewModel.commitRejectionReason == .fewerThanTwoPorts)
}

@Test("scenario: cancel discards in-progress route")
@MainActor
func scenarioCancelDiscardsInProgressRoute() {
    let fixture = makeShoreSnapshot(); let snap = fixture.snapshot; let portA = fixture.portA; let portB = fixture.portB
    let (viewModel, captured) = makeViewModel(snapshot: snap)
    viewModel.tapHandler(target: .port(id: portA))
    viewModel.tapHandler(target: .port(id: portB))
    viewModel.setManifest([.loadUpTo(good: .wood, qty: 10)], forPort: portA)
    viewModel.cancel()
    #expect(viewModel.inProgressWaypoints.isEmpty)
    #expect(viewModel.manifest.isEmpty)
    #expect(captured().isEmpty)
}

// MARK: - Manifest editor surface

@Test("scenario: manifest editor preserves actions across taps")
@MainActor
func scenarioManifestEditorPreservesActionsAcrossTaps() {
    let fixture = makeShoreSnapshot(); let snap = fixture.snapshot; let portA = fixture.portA; let portB = fixture.portB
    let (viewModel, _) = makeViewModel(snapshot: snap)
    viewModel.tapHandler(target: .port(id: portA))
    viewModel.setManifest([
        .unloadUpTo(good: .planks, qty: 30),
        .loadUpTo(good: .wood, qty: 50)
    ], forPort: portA)
    viewModel.tapHandler(target: .port(id: portB))
    #expect(viewModel.manifest[portA]?.count == 2)
    #expect(viewModel.manifest[portB] == nil)
}

// MARK: - Route list view-model

@Test("scenario: route list reflects snapshot in deterministic order")
@MainActor
func scenarioRouteListReflectsSnapshotInDeterministicOrder() {
    var world = World.fixtureWithTerrain(width: 4, height: 4, fill: .water, seed: 1)
    let routeA = EntityID(raw: 50)
    let routeB = EntityID(raw: 30) // smaller raw → comes first
    world.routes[routeA] = Route(
        id: routeA, waypoints: [], manifest: [:],
        speed: .one, state: .active
    )
    world.routes[routeB] = Route(
        id: routeB, waypoints: [], manifest: [:],
        speed: .one, state: .active
    )
    let viewModel = RouteListViewModel()
    viewModel.snapshot = world.snapshot()
    let ids = viewModel.routes.map(\.id)
    #expect(ids == [routeB, routeA])
}

@Test("scenario: route list select updates current selection")
@MainActor
func scenarioRouteListSelectUpdatesCurrentSelection() {
    var world = World.fixtureWithTerrain(width: 4, height: 4, fill: .water, seed: 1)
    let routeID = EntityID(raw: 77)
    world.routes[routeID] = Route(
        id: routeID, waypoints: [], manifest: [:],
        speed: .one, state: .active
    )
    let viewModel = RouteListViewModel()
    viewModel.snapshot = world.snapshot()
    viewModel.select(routeID)
    #expect(viewModel.selectedRouteID == routeID)
    viewModel.select(nil)
    #expect(viewModel.selectedRouteID == nil)
}

@Test("scenario: route list delete issues deleteroute command")
@MainActor
func scenarioRouteListDeleteIssuesDeleteRouteCommand() {
    var captured: [Command] = []
    let viewModel = RouteListViewModel(commandSink: { captured.append($0) })
    var world = World.fixtureWithTerrain(width: 4, height: 4, fill: .water, seed: 1)
    let routeID = EntityID(raw: 88)
    world.routes[routeID] = Route(
        id: routeID, waypoints: [], manifest: [:],
        speed: .one, state: .active
    )
    viewModel.snapshot = world.snapshot()
    viewModel.select(routeID)
    viewModel.delete(routeID)
    if case let .deleteRoute(id) = captured.last {
        #expect(id == routeID)
    } else {
        Issue.record("expected deleteRoute command")
    }
    #expect(viewModel.selectedRouteID == nil)
}

@Test("scenario: manifest editor clears actions when empty")
@MainActor
func scenarioManifestEditorClearsActionsWhenEmpty() {
    let fixture = makeShoreSnapshot(); let snap = fixture.snapshot; let portA = fixture.portA
    let (viewModel, _) = makeViewModel(snapshot: snap)
    viewModel.setManifest([.loadUpTo(good: .wood, qty: 1)], forPort: portA)
    #expect(viewModel.manifest[portA]?.count == 1)
    viewModel.setManifest([], forPort: portA)
    #expect(viewModel.manifest[portA] == nil)
}
