import Foundation
import Testing
@testable import CityCore

// Tests for the M5 ship tick system. Maps `#### Scenario:` headings
// from openspec/changes/add-archipelago-and-sea/specs/sea-transport/spec.md
// under Requirements `Ship state machine`, `Per-tick ship integration`,
// `Dock timeout policy`, `Multiple ships per route`, and `Manifest
// actions`.

private func shoreWorld(width: Int = 16, height: Int = 12) -> World {
    var world = World.fixtureWithTerrain(width: width, height: height, fill: .grass, seed: 11)
    for tileY in 0 ..< world.mapHeight {
        for tileX in 8 ..< world.mapWidth {
            world.terrainGrid[tileY * world.mapWidth + tileX] = .water
        }
    }
    world.economy.credit(100_000)
    return world
}

private func placePort(_ world: inout World, at anchor: TileCoordinate) -> EntityID {
    world.pendingCommands.append(.place(.port, at: anchor))
    _ = world.tick()
    return world.occupiedTiles[anchor]!
}

private func makeShip(
    _ world: inout World, id: UInt32, position: Fixed2D = .zero, heading: Fixed = .zero,
    routeID: EntityID? = nil, waypointIdx: Int = 0, cargo: [Good: Int] = [:],
    state: ShipState = .idle
) -> EntityID {
    let shipID = EntityID(raw: id)
    world.ships[shipID] = Ship(
        id: shipID, position: position, heading: heading,
        routeID: routeID, waypointIdx: waypointIdx, cargo: cargo,
        state: state, shipClass: .default
    )
    return shipID
}

private func waterRoute(
    _ world: inout World, id: UInt32,
    waypoints: [Waypoint],
    manifest: [PortID: [ManifestAction]] = [:],
    speed: Fixed = .one
) -> EntityID {
    let routeID = EntityID(raw: id)
    world.routes[routeID] = Route(
        id: routeID, waypoints: waypoints, manifest: manifest,
        speed: speed, state: .active
    )
    return routeID
}

// MARK: - Ship state machine

@Test("scenario: idle ship transitions to sailing on route assignment")
func scenarioIdleShipTransitionsToSailingOnRouteAssignment() throws {
    var world = shoreWorld()
    let portA = placePort(&world, at: TileCoordinate(x: 7, y: 1))
    let portB = placePort(&world, at: TileCoordinate(x: 7, y: 5))
    let routeID = waterRoute(&world, id: 100, waypoints: [.port(id: portA), .port(id: portB)])
    let shipID = makeShip(&world, id: 200, position: Fixed2D(x: Fixed(10), y: Fixed(3)))
    world.pendingCommands.append(.assignShipToRoute(shipID: shipID, routeID: routeID))
    _ = world.tick()
    let ship = try #require(world.ships[shipID])
    #expect(ship.state == .sailing)
    #expect(ship.routeID == routeID)
}

@Test("scenario: sailing ship docks on arrival at port waypoint")
func scenarioSailingShipDocksOnArrivalAtPortWaypoint() throws {
    var world = shoreWorld()
    let portA = placePort(&world, at: TileCoordinate(x: 7, y: 1))
    let portB = placePort(&world, at: TileCoordinate(x: 7, y: 5))
    let routeID = waterRoute(&world, id: 101, waypoints: [.port(id: portA), .port(id: portB)])
    let port = try #require(world.buildings[portA])
    let anchor = try #require(port.shipAnchor)
    // Spawn the ship 0.1 tile away from the port anchor (well inside
    // arrival epsilon = 0.25 once a tick of integration happens).
    let near = Fixed2D(
        x: Fixed(raw: Int32(anchor.x) &* Fixed.scale &+ 100),
        y: Fixed(raw: Int32(anchor.y) &* Fixed.scale)
    )
    let shipID = makeShip(
        &world, id: 201, position: near, routeID: routeID,
        waypointIdx: 0, state: .sailing
    )
    _ = world.tick()
    let ship = try #require(world.ships[shipID])
    #expect(ship.state == .docked)
}

@Test("scenario: broken route triggers returning state")
func scenarioBrokenRouteTriggersReturningState() {
    var world = shoreWorld()
    let portA = placePort(&world, at: TileCoordinate(x: 7, y: 1))
    let portB = placePort(&world, at: TileCoordinate(x: 7, y: 5))
    let routeID = waterRoute(&world, id: 102, waypoints: [.port(id: portA), .port(id: portB)])
    let shipID = makeShip(
        &world, id: 202, position: Fixed2D(x: Fixed(10), y: Fixed(3)),
        routeID: routeID, state: .sailing
    )
    world.routes[routeID]?.state = .broken(reason: .unknownPort(portID: portB))
    _ = world.tick()
    #expect(world.ships[shipID]?.state == .returning)
}

@Test("scenario: returning ship becomes idle on reaching a port")
func scenarioReturningShipBecomesIdleOnReachingAPort() throws {
    var world = shoreWorld()
    let portA = placePort(&world, at: TileCoordinate(x: 7, y: 1))
    let port = try #require(world.buildings[portA])
    let anchor = try #require(port.shipAnchor)
    let near = Fixed2D(
        x: Fixed(raw: Int32(anchor.x) &* Fixed.scale &+ 200),
        y: Fixed(raw: Int32(anchor.y) &* Fixed.scale)
    )
    let shipID = makeShip(&world, id: 203, position: near, routeID: nil, state: .returning)
    _ = world.tick()
    let ship = try #require(world.ships[shipID])
    #expect(ship.state == .idle)
    #expect(ship.routeID == nil)
}

// MARK: - Per-tick ship integration

@Test("scenario: ship reaches a waypoint within n ticks")
func scenarioShipReachesAWaypointWithinNTicks() throws {
    var world = shoreWorld(width: 20, height: 12)
    // Both ports straddle the x=7/8 shoreline; distance ≈ 7 tiles in y.
    let portA = placePort(&world, at: TileCoordinate(x: 7, y: 1))
    let portB = placePort(&world, at: TileCoordinate(x: 7, y: 8))
    // Port B has an empty-stock load action so the ship stalls in
    // `.docked` once it arrives — observable end state.
    let routeID = waterRoute(
        &world, id: 110,
        waypoints: [.port(id: portA), .port(id: portB)],
        manifest: [portB: [.loadUpTo(good: .wood, qty: 1)]],
        speed: Fixed(raw: 2048) // 0.5 tile/tick
    )
    let portABuilding = try #require(world.buildings[portA])
    let aAnchor = try #require(portABuilding.shipAnchor)
    let start = Fixed2D(
        x: Fixed(Int32(aAnchor.x)),
        y: Fixed(Int32(aAnchor.y))
    )
    let shipID = makeShip(
        &world, id: 210, position: start,
        routeID: routeID, waypointIdx: 1, state: .sailing
    )
    // distance ≈ 7 tiles, speed 0.5 → 14 ticks minimum; budget +2.
    for _ in 0 ..< 16 {
        _ = world.tick()
    }
    let ship = try #require(world.ships[shipID])
    #expect(ship.state == .docked, "expected ship to have docked at port B within budget")
}

@Test("scenario: heading is updated to match motion direction")
func scenarioHeadingIsUpdatedToMatchMotionDirection() throws {
    var world = shoreWorld(width: 12, height: 14)
    let portA = placePort(&world, at: TileCoordinate(x: 7, y: 1))
    let portB = placePort(&world, at: TileCoordinate(x: 7, y: 10))
    let routeID = waterRoute(
        &world, id: 111,
        waypoints: [.port(id: portA), .port(id: portB)],
        speed: Fixed(raw: 2048)
    )
    // Position the ship directly north of port B's anchor so motion
    // is pure south — heading must be near π/2.
    let portBBuilding = try #require(world.buildings[portB])
    let bAnchor = try #require(portBBuilding.shipAnchor)
    let start = Fixed2D(
        x: Fixed(Int32(bAnchor.x)),
        y: Fixed(Int32(bAnchor.y) - 5)
    )
    let shipID = makeShip(
        &world, id: 211, position: start,
        routeID: routeID, waypointIdx: 1, state: .sailing
    )
    _ = world.tick()
    let ship = try #require(world.ships[shipID])
    let halfPi = Fixed(raw: 6434) // π/2 ≈ 1.5708, in Fixed scale=4096 ≈ 6434
    let delta = ship.heading.raw - halfPi.raw
    #expect(abs(delta) < 200, "heading \(ship.heading.raw) should be near π/2 (\(halfPi.raw))")
}

// MARK: - Dock timeout policy

@Test("scenario: ship waits when port is empty")
func scenarioShipWaitsWhenPortIsEmpty() throws {
    var world = shoreWorld()
    let portA = placePort(&world, at: TileCoordinate(x: 7, y: 1))
    let portB = placePort(&world, at: TileCoordinate(x: 7, y: 5))
    let routeID = waterRoute(
        &world, id: 120,
        waypoints: [.port(id: portA), .port(id: portB)],
        manifest: [portA: [.loadUpTo(good: .wood, qty: 50)]]
    )
    let portABuilding = try #require(world.buildings[portA])
    let anchor = try #require(portABuilding.shipAnchor)
    let pos = Fixed2D(x: Fixed(Int32(anchor.x)), y: Fixed(Int32(anchor.y)))
    let shipID = makeShip(
        &world, id: 220, position: pos,
        routeID: routeID, waypointIdx: 0, state: .docked
    )
    // Port has 0 wood — ship cannot make progress. After 1 tick still docked.
    _ = world.tick()
    let ship = try #require(world.ships[shipID])
    #expect(ship.state == .docked)
    #expect((ship.cargo[.wood] ?? 0) == 0)
}

@Test("scenario: ship advances past empty-port action after timeout")
func scenarioShipAdvancesPastEmptyPortActionAfterTimeout() throws {
    var world = shoreWorld(width: 16, height: 12)
    let portA = placePort(&world, at: TileCoordinate(x: 7, y: 1))
    let portB = placePort(&world, at: TileCoordinate(x: 7, y: 8))
    let routeID = waterRoute(
        &world, id: 121,
        waypoints: [.port(id: portA), .port(id: portB)],
        manifest: [portA: [.loadUpTo(good: .wood, qty: 50)]],
        speed: Fixed(raw: 2048)
    )
    let portABuilding = try #require(world.buildings[portA])
    let anchor = try #require(portABuilding.shipAnchor)
    let pos = Fixed2D(x: Fixed(Int32(anchor.x)), y: Fixed(Int32(anchor.y)))
    let shipID = makeShip(
        &world, id: 221, position: pos,
        routeID: routeID, waypointIdx: 0, state: .docked
    )
    for _ in 0 ... World.shipDockTimeout {
        _ = world.tick()
    }
    let ship = try #require(world.ships[shipID])
    // After timeout the empty action is skipped; manifest exhausted →
    // ship transitions back to sailing toward port B.
    #expect(ship.state == .sailing)
    #expect(ship.waypointIdx == 1)
}

@Test("scenario: ship resumes sailing after partial manifest completion")
func scenarioShipResumesSailingAfterPartialManifestCompletion() throws {
    var world = shoreWorld()
    let portA = placePort(&world, at: TileCoordinate(x: 7, y: 1))
    let portB = placePort(&world, at: TileCoordinate(x: 7, y: 5))
    // Manifest: load 10 wood. Port has 30.
    if var sp = world.stockpiles[portA] {
        _ = sp.deposit(.wood, amount: 30)
        world.stockpiles[portA] = sp
    }
    let routeID = waterRoute(
        &world, id: 122,
        waypoints: [.port(id: portA), .port(id: portB)],
        manifest: [portA: [.loadUpTo(good: .wood, qty: 10)]]
    )
    let portABuilding = try #require(world.buildings[portA])
    let anchor = try #require(portABuilding.shipAnchor)
    let pos = Fixed2D(x: Fixed(Int32(anchor.x)), y: Fixed(Int32(anchor.y)))
    let shipID = makeShip(
        &world, id: 222, position: pos,
        routeID: routeID, waypointIdx: 0, state: .docked
    )
    _ = world.tick()
    let ship = try #require(world.ships[shipID])
    #expect(ship.state == .sailing)
    #expect(ship.waypointIdx == 1)
    #expect(ship.cargo[.wood] == 10)
}

// MARK: - Multiple ships per route

@Test("scenario: two ships assigned to same route operate independently")
func scenarioTwoShipsAssignedToSameRouteOperateIndependently() throws {
    var world = shoreWorld()
    let portA = placePort(&world, at: TileCoordinate(x: 7, y: 1))
    let portB = placePort(&world, at: TileCoordinate(x: 7, y: 5))
    let routeID = waterRoute(&world, id: 130, waypoints: [.port(id: portA), .port(id: portB)])
    let shipA = makeShip(
        &world, id: 230, position: Fixed2D(x: Fixed(10), y: Fixed(2)),
        routeID: routeID, waypointIdx: 0, state: .sailing
    )
    let shipB = makeShip(
        &world, id: 231, position: Fixed2D(x: Fixed(11), y: Fixed(4)),
        routeID: routeID, waypointIdx: 1, state: .sailing
    )
    _ = world.tick()
    let shipAState = try #require(world.ships[shipA])
    let shipBState = try #require(world.ships[shipB])
    // Each ship integrates toward its own target without interfering.
    #expect(shipAState.position != Fixed2D(x: Fixed(10), y: Fixed(2)))
    #expect(shipBState.position != Fixed2D(x: Fixed(11), y: Fixed(4)))
}

@Test("scenario: two ships at the same position do not interfere")
func scenarioTwoShipsAtTheSamePositionDoNotInterfere() throws {
    var world = shoreWorld()
    let portA = placePort(&world, at: TileCoordinate(x: 7, y: 1))
    let portB = placePort(&world, at: TileCoordinate(x: 7, y: 5))
    let routeID = waterRoute(&world, id: 131, waypoints: [.port(id: portA), .port(id: portB)])
    let same = Fixed2D(x: Fixed(10), y: Fixed(3))
    let shipA = makeShip(
        &world, id: 240, position: same, routeID: routeID,
        waypointIdx: 1, state: .sailing
    )
    let shipB = makeShip(
        &world, id: 241, position: same, routeID: routeID,
        waypointIdx: 1, state: .sailing
    )
    _ = world.tick()
    let shipAState = try #require(world.ships[shipA])
    let shipBState = try #require(world.ships[shipB])
    // Same target → same advance → both remain at identical positions.
    #expect(shipAState.position == shipBState.position)
    #expect(shipAState.state == shipBState.state)
}
