import Foundation
import Testing
@testable import CityCore

// sea-transport scenarios of openspec/changes/add-route-authoring-ui
// (Pausing a route).

/// Land west of x = 8, water east of it, two player ports on the shore
/// and an active route between them.
private struct PauseFixture {
    var world: World
    let portA: EntityID
    let portB: EntityID
    let route: EntityID
}

private func pauseFixture() throws -> PauseFixture {
    var world = World.fixtureWithTerrain(width: 16, height: 12, fill: .grass, seed: 11)
    for tileY in 0 ..< world.mapHeight {
        for tileX in 8 ..< world.mapWidth {
            world.terrainGrid[tileY * world.mapWidth + tileX] = .water
        }
    }
    world.economy.credit(100_000)
    world.islands = IslandDetector.detectIslands(
        width: world.mapWidth, height: world.mapHeight, terrain: world.terrainGrid,
        mapHeightForClimate: world.mapHeight, seed: 11
    )
    world.seedUnlimitedTestInventory()
    world.pendingCommands.append(.place(.port, at: TileCoordinate(x: 7, y: 1)))
    world.pendingCommands.append(.place(.port, at: TileCoordinate(x: 7, y: 5)))
    _ = world.tick()
    let portA = try #require(world.occupiedTiles[TileCoordinate(x: 7, y: 1)])
    let portB = try #require(world.occupiedTiles[TileCoordinate(x: 7, y: 5)])
    let route = EntityID(raw: 900)
    world.routes[route] = Route(
        id: route, waypoints: [.port(id: portA), .port(id: portB)],
        manifest: [portA: [.unloadUpTo(good: .wood, qty: 10)]], speed: .one, state: .active
    )
    return PauseFixture(world: world, portA: portA, portB: portB, route: route)
}

private func addShip(
    _ world: inout World, id: UInt32, at position: Fixed2D, route: EntityID,
    state: ShipState, cargo: [Good: Int] = [:]
) -> EntityID {
    let shipID = EntityID(raw: id)
    world.ships[shipID] = Ship(
        id: shipID, position: position, heading: .zero, routeID: route, waypointIdx: 0,
        cargo: cargo, state: state, shipClass: .default
    )
    return shipID
}

@Test("scenario: paused route holds its ships")
func scenarioPausedRouteHoldsItsShips() throws {
    var fixture = try pauseFixture()
    let dock = fixture.world.shipTargetPosition(for: .port(id: fixture.portA))
    let start = Fixed2D(x: Fixed(12), y: Fixed(8))
    let sailing = addShip(&fixture.world, id: 901, at: start, route: fixture.route, state: .sailing)
    let docked = addShip(&fixture.world, id: 902, at: dock, route: fixture.route, state: .docked, cargo: [.wood: 10])
    fixture.world.pendingCommands.append(.setRoutePaused(id: fixture.route, paused: true))
    _ = fixture.world.testRun(ticks: 10)
    #expect(fixture.world.routes[fixture.route]?.state == .paused)
    #expect(fixture.world.ships[sailing]?.position == start)
    #expect(fixture.world.ships[sailing]?.state == .sailing)
    #expect(fixture.world.ships[docked]?.cargo == [.wood: 10])
    #expect(fixture.world.ships[docked]?.dockedManifestIndex == 0)
    #expect(fixture.world.ships[docked]?.state == .docked)
}

@Test("a docked ship unloads once its route is unpaused")
func dockedShipUnloadsWithoutPause() throws {
    var fixture = try pauseFixture()
    let dock = fixture.world.shipTargetPosition(for: .port(id: fixture.portA))
    let docked = addShip(&fixture.world, id: 902, at: dock, route: fixture.route, state: .docked, cargo: [.wood: 10])
    _ = fixture.world.tick()
    #expect(fixture.world.ships[docked]?.cargo[.wood, default: 0] == 0)
}

@Test("scenario: resumed route sails on")
func scenarioResumedRouteSailsOn() throws {
    var fixture = try pauseFixture()
    fixture.world.routes[fixture.route]?.state = .paused
    let start = Fixed2D(x: Fixed(12), y: Fixed(8))
    let sailing = addShip(&fixture.world, id: 901, at: start, route: fixture.route, state: .sailing)
    _ = fixture.world.tick()
    #expect(fixture.world.ships[sailing]?.position == start)
    fixture.world.pendingCommands.append(.setRoutePaused(id: fixture.route, paused: false))
    _ = fixture.world.tick()
    #expect(fixture.world.routes[fixture.route]?.state == .active)
    #expect(fixture.world.ships[sailing]?.position != start)
}

@Test("scenario: broken route stays broken")
func scenarioBrokenRouteStaysBroken() throws {
    var fixture = try pauseFixture()
    let broken = RouteState.broken(reason: .unknownPort(portID: fixture.portB))
    fixture.world.routes[fixture.route]?.state = broken
    fixture.world.pendingCommands.append(.setRoutePaused(id: fixture.route, paused: false))
    fixture.world.pendingCommands.append(.setRoutePaused(id: fixture.route, paused: true))
    _ = fixture.world.tick()
    #expect(fixture.world.routes[fixture.route]?.state == broken)
}

@Test("pausing an unknown route changes nothing")
func pausingUnknownRouteIsIgnored() throws {
    var fixture = try pauseFixture()
    fixture.world.pendingCommands.append(.setRoutePaused(id: EntityID(raw: 12345), paused: true))
    _ = fixture.world.tick()
    #expect(fixture.world.routes[fixture.route]?.state == .active)
    #expect(fixture.world.routes[EntityID(raw: 12345)] == nil)
}

@Test("demolishing a port leaves ships on an unrelated paused route alone")
func demolishLeavesUnrelatedPausedRoute() throws {
    var fixture = try pauseFixture()
    fixture.world.routes[fixture.route]?.state = .paused
    let start = Fixed2D(x: Fixed(12), y: Fixed(8))
    let sailing = addShip(&fixture.world, id: 901, at: start, route: fixture.route, state: .sailing)
    fixture.world.pendingCommands.append(.place(.port, at: TileCoordinate(x: 7, y: 9)))
    _ = fixture.world.tick()
    #expect(fixture.world.occupiedTiles[TileCoordinate(x: 7, y: 9)] != nil)
    fixture.world.pendingCommands.append(.demolish(at: TileCoordinate(x: 7, y: 9)))
    _ = fixture.world.tick()
    #expect(fixture.world.occupiedTiles[TileCoordinate(x: 7, y: 9)] == nil)
    #expect(fixture.world.ships[sailing]?.state == .sailing)
}
