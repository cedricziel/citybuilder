import Foundation
import Testing
@testable import CityCore

// Tests for the M3 route validation + lifecycle commands of
// add-archipelago-and-sea. Each `#### Scenario:` in
// openspec/changes/add-archipelago-and-sea/specs/sea-transport/spec.md
// under Requirements `Route entity`, `Waypoint kinds`, `Route
// validation`, and `Route lifecycle commands` maps here.
//
// Manifest-execution scenarios (`Manifest actions`) are M5 (tick-time
// dock execution) and intentionally not asserted in this file.

private func waterWorld(width: Int = 16, height: Int = 16) -> World {
    World.fixtureWithTerrain(width: width, height: height, fill: .water, seed: 31)
}

private func placeStandInPort(_ world: inout World, at anchor: TileCoordinate) -> PortID {
    let id = EntityID(raw: world.nextEntityRaw)
    world.nextEntityRaw &+= 1
    // M3 stand-in: any extant building counts as a port. M4 narrows
    // the predicate to `kind == .port` once Port lands as a real
    // BuildingKind. Using `.warehouse` here keeps catalog lookups
    // valid.
    let building = Building(id: id, kind: .warehouse, anchor: anchor, state: .operational)
    world.buildings[id] = building
    world.occupiedTiles[anchor] = id
    return id
}

// MARK: - Route entity

@Test("scenario: route persists after assigned ship is destroyed")
func scenarioRoutePersistsAfterAssignedShipIsDestroyed() {
    var world = waterWorld()
    let routeID = EntityID(raw: 1000)
    world.routes[routeID] = Route(
        id: routeID,
        waypoints: [.sea(position: .zero), .sea(position: Fixed2D(x: Fixed(1), y: Fixed(1)))],
        manifest: [:],
        speed: Fixed(raw: 410),
        state: .active
    )
    let shipID = EntityID(raw: 2000)
    world.ships[shipID] = Ship(
        id: shipID, position: .zero, heading: .zero,
        routeID: routeID, waypointIdx: 0, cargo: [:],
        state: .sailing, shipClass: .default
    )
    world.ships.removeValue(forKey: shipID)
    #expect(world.routes[routeID] != nil)
    #expect(world.routes[routeID]?.waypoints.count == 2)
}

@Test("scenario: route requires at least two port waypoints")
func scenarioRouteRequiresAtLeastTwoPortWaypoints() {
    var world = waterWorld()
    let portA = placeStandInPort(&world, at: TileCoordinate(x: 0, y: 0))
    let route = Route(
        id: EntityID(raw: 9001),
        waypoints: [.port(id: portA), .sea(position: Fixed2D(x: Fixed(5), y: Fixed(5)))],
        manifest: [:],
        speed: Fixed(raw: 410),
        state: .active
    )
    let result = world.validate(route: route)
    if case let .invalid(reason) = result {
        #expect(reason == .fewerThanTwoPorts)
    } else {
        Issue.record("expected .invalid(.fewerThanTwoPorts), got \(result)")
    }
}

// MARK: - Waypoint kinds

@Test("scenario: sea waypoint position lies on water tile")
func scenarioSeaWaypointPositionLiesOnWaterTile() {
    var world = waterWorld()
    // Force tile (1,1) to grass; a sea waypoint over it must reject.
    world.terrainGrid[1 * world.mapWidth + 1] = .grass
    let portA = placeStandInPort(&world, at: TileCoordinate(x: 5, y: 5))
    let portB = placeStandInPort(&world, at: TileCoordinate(x: 7, y: 7))
    let badSea = Fixed2D(x: Fixed(raw: 4096 + 100), y: Fixed(raw: 4096 + 100))
    let route = Route(
        id: EntityID(raw: 9002),
        waypoints: [.port(id: portA), .sea(position: badSea), .port(id: portB)],
        manifest: [:],
        speed: Fixed(raw: 410),
        state: .active
    )
    let result = world.validate(route: route)
    if case .invalid(.segmentCrossesLand) = result {
        // Either flagged at segment-level OR tile-level — both correct.
    } else {
        Issue.record("expected .invalid land-related, got \(result)")
    }
}

@Test("scenario: port waypoint references an existing port")
func scenarioPortWaypointReferencesAnExistingPort() {
    var world = waterWorld()
    let portA = placeStandInPort(&world, at: TileCoordinate(x: 2, y: 2))
    let portB = placeStandInPort(&world, at: TileCoordinate(x: 8, y: 8))
    let route = Route(
        id: EntityID(raw: 9003),
        waypoints: [.port(id: portA), .port(id: portB)],
        manifest: [:],
        speed: Fixed(raw: 410),
        state: .active
    )
    #expect(world.validate(route: route) == .valid)
}

// MARK: - Route validation

@Test("scenario: route with land-crossing segment is invalid")
func scenarioRouteWithLandCrossingSegmentIsInvalid() {
    var world = waterWorld(width: 12, height: 4)
    // Create a vertical wall of grass at x=6 so any segment from x<6
    // to x>6 must cross land.
    for tileY in 0 ..< world.mapHeight {
        world.terrainGrid[tileY * world.mapWidth + 6] = .grass
    }
    let portA = placeStandInPort(&world, at: TileCoordinate(x: 1, y: 1))
    let portB = placeStandInPort(&world, at: TileCoordinate(x: 10, y: 1))
    let route = Route(
        id: EntityID(raw: 9004),
        waypoints: [.port(id: portA), .port(id: portB)],
        manifest: [:],
        speed: Fixed(raw: 410),
        state: .active
    )
    let result = world.validate(route: route)
    if case let .invalid(.segmentCrossesLand(idx)) = result {
        #expect(idx == 0)
    } else {
        Issue.record("expected .invalid(.segmentCrossesLand(0)), got \(result)")
    }
}

@Test("scenario: route referencing a non-existent port is invalid")
func scenarioRouteReferencingANonExistentPortIsInvalid() {
    var world = waterWorld()
    let portA = placeStandInPort(&world, at: TileCoordinate(x: 0, y: 0))
    let phantom = EntityID(raw: 0xDEAD)
    let route = Route(
        id: EntityID(raw: 9005),
        waypoints: [.port(id: portA), .port(id: phantom)],
        manifest: [:],
        speed: Fixed(raw: 410),
        state: .active
    )
    let result = world.validate(route: route)
    if case let .invalid(.unknownPort(id)) = result {
        #expect(id == phantom)
    } else {
        Issue.record("expected .invalid(.unknownPort(\(phantom))), got \(result)")
    }
}

@Test("scenario: valid route validates as active")
func scenarioValidRouteValidatesAsActive() {
    var world = waterWorld()
    let portA = placeStandInPort(&world, at: TileCoordinate(x: 2, y: 2))
    let portB = placeStandInPort(&world, at: TileCoordinate(x: 8, y: 8))
    let route = Route(
        id: EntityID(raw: 9006),
        waypoints: [
            .port(id: portA),
            .sea(position: Fixed2D(x: Fixed(5), y: Fixed(5))),
            .port(id: portB)
        ],
        manifest: [:],
        speed: Fixed(raw: 410),
        state: .active
    )
    #expect(world.validate(route: route) == .valid)
}

@Test("scenario: segment sampling resolution is sub-tile")
func scenarioSegmentSamplingResolutionIsSubTile() {
    var world = waterWorld(width: 10, height: 10)
    // Place a single land tile at (5,5) — the diagonal segment between
    // (4.0, 4.0) and (6.0, 6.0) passes through the *corner* of (5,5).
    // A sampling step coarser than 0.25 might miss it; the validator
    // MUST catch it.
    world.terrainGrid[5 * world.mapWidth + 5] = .grass
    let portA = placeStandInPort(&world, at: TileCoordinate(x: 4, y: 4))
    let portB = placeStandInPort(&world, at: TileCoordinate(x: 6, y: 6))
    let route = Route(
        id: EntityID(raw: 9007),
        waypoints: [.port(id: portA), .port(id: portB)],
        manifest: [:],
        speed: Fixed(raw: 410),
        state: .active
    )
    let result = world.validate(route: route)
    if case .invalid(.segmentCrossesLand) = result {
        // Validator caught it via sub-tile sampling.
    } else {
        Issue.record("expected .invalid(.segmentCrossesLand), got \(result)")
    }
}

// MARK: - Lifecycle commands

@Test("scenario: createroute rejected when validation fails")
func scenarioCreateRouteRejectedWhenValidationFails() {
    var world = waterWorld()
    let portA = placeStandInPort(&world, at: TileCoordinate(x: 0, y: 0))
    let countBefore = world.routes.count
    world.pendingCommands.append(.createRoute(
        waypoints: [.port(id: portA)], // only one port — invalid
        manifest: [:],
        speed: Fixed(raw: 410)
    ))
    _ = world.tick()
    #expect(world.routes.count == countBefore, "invalid CreateRoute must not add a route")
}

@Test("scenario: editroute recomputes ship waypoint index")
func scenarioEditRouteRecomputesShipWaypointIndex() {
    var world = waterWorld()
    let portA = placeStandInPort(&world, at: TileCoordinate(x: 2, y: 2))
    let portB = placeStandInPort(&world, at: TileCoordinate(x: 8, y: 8))
    let portC = placeStandInPort(&world, at: TileCoordinate(x: 14, y: 2))
    let routeID = EntityID(raw: 9100)
    world.routes[routeID] = Route(
        id: routeID,
        waypoints: [.port(id: portA), .port(id: portB), .port(id: portC)],
        manifest: [:],
        speed: Fixed(raw: 410),
        state: .active
    )
    let shipID = EntityID(raw: 9200)
    world.ships[shipID] = Ship(
        id: shipID,
        position: Fixed2D(x: Fixed(5), y: Fixed(5)),
        heading: Fixed.zero,
        routeID: routeID, waypointIdx: 2,
        cargo: [:], state: .sailing, shipClass: .default
    )
    // EditRoute drops portC; the ship's waypointIdx was 2 (portC)
    // which no longer exists — it must reset to a valid index.
    world.pendingCommands.append(.editRoute(
        id: routeID,
        waypoints: [.port(id: portA), .port(id: portB)],
        manifest: [:]
    ))
    _ = world.tick()
    let recomputed = world.ships[shipID]?.waypointIdx ?? -1
    #expect(recomputed >= 0 && recomputed < 2)
}

@Test("scenario: deleteroute idles all assigned ships")
func scenarioDeleteRouteIdlesAllAssignedShips() {
    var world = waterWorld()
    let portA = placeStandInPort(&world, at: TileCoordinate(x: 2, y: 2))
    let portB = placeStandInPort(&world, at: TileCoordinate(x: 8, y: 8))
    let routeID = EntityID(raw: 9101)
    world.routes[routeID] = Route(
        id: routeID,
        waypoints: [.port(id: portA), .port(id: portB)],
        manifest: [:],
        speed: Fixed(raw: 410),
        state: .active
    )
    for shipRaw: UInt32 in [9301, 9302, 9303] {
        world.ships[EntityID(raw: shipRaw)] = Ship(
            id: EntityID(raw: shipRaw),
            position: .zero, heading: .zero,
            routeID: routeID, waypointIdx: 0,
            cargo: [:], state: .sailing, shipClass: .default
        )
    }
    world.pendingCommands.append(.deleteRoute(id: routeID))
    _ = world.tick()
    #expect(world.routes[routeID] == nil)
    for shipRaw: UInt32 in [9301, 9302, 9303] {
        let ship = world.ships[EntityID(raw: shipRaw)]
        #expect(ship?.state == .returning)
    }
}
