import Foundation
import Testing
@testable import CityCore

// Tests for the M4 Port + Shipyard building kinds. Covers the
// data-level + command-time scenarios from
// openspec/changes/add-archipelago-and-sea/specs/port-and-shipyard/spec.md.
// Carrier-deposit / ship-dock scenarios (which depend on the M5 tick
// systems) are intentionally deferred.

private func shoreWorld(width: Int = 12, height: Int = 6) -> World {
    var world = World.fixtureWithTerrain(width: width, height: height, fill: .grass, seed: 7)
    for tileY in 0 ..< world.mapHeight {
        for tileX in 6 ..< world.mapWidth {
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

private func placeShipyard(_ world: inout World, at anchor: TileCoordinate) -> EntityID {
    world.pendingCommands.append(.place(.shipyard, at: anchor))
    _ = world.tick()
    return world.occupiedTiles[anchor]!
}

// MARK: - Port placement

@Test("scenario: port placed straddling shore")
func scenarioPortPlacedStraddlingShore() throws {
    var world = shoreWorld()
    let portID = placePort(&world, at: TileCoordinate(x: 5, y: 1))
    let port = try #require(world.buildings[portID])
    #expect(port.kind == .port)
    #expect(port.shipAnchor != nil)
    let anchor = try #require(port.shipAnchor)
    #expect(world.terrain(at: anchor) == .water)
}

@Test("scenario: port placement on all-land footprint rejected")
func scenarioPortPlacementOnAllLandFootprintRejected() {
    let world = shoreWorld()
    // (1,1)..(2,3) is all-grass — port should reject.
    #expect(world.canPlace(.port, at: TileCoordinate(x: 1, y: 1))
        == .rejected(.shoreRequiresWaterTile))
}

@Test("scenario: port placement on all-water footprint rejected")
func scenarioPortPlacementOnAllWaterFootprintRejected() {
    let world = shoreWorld()
    // (7,1)..(8,3) is all-water.
    #expect(world.canPlace(.port, at: TileCoordinate(x: 7, y: 1))
        == .rejected(.shoreRequiresLandTile))
}

// MARK: - Single port stock view across faces

@Test("scenario: single port stock view across faces")
func scenarioSinglePortStockViewAcrossFaces() {
    var world = shoreWorld()
    let portID = placePort(&world, at: TileCoordinate(x: 5, y: 1))
    // Mirroring the spec scenario: a sea-side deposit and a land-side
    // query both consult the same Stockpile.
    if var stockpile = world.stockpiles[portID] {
        _ = stockpile.deposit(.wood, amount: 25)
        world.stockpiles[portID] = stockpile
    }
    let seaSideStock = world.stockpiles[portID]?.quantity(of: .wood) ?? 0
    let landSideStock = world.stockpiles[portID]?.quantity(of: .wood) ?? 0
    #expect(seaSideStock == 25)
    #expect(landSideStock == seaSideStock)
}

// MARK: - Port road connectivity

@Test("scenario: disconnected port refuses carrier service")
func scenarioDisconnectedPortRefusesCarrierService() throws {
    var world = shoreWorld()
    let portID = placePort(&world, at: TileCoordinate(x: 5, y: 1))
    let port = try #require(world.buildings[portID])
    #expect(!world.isRoadConnected(building: port))
}

@Test("scenario: adjacent road connects port")
func scenarioAdjacentRoadConnectsPort() throws {
    var world = shoreWorld()
    let portID = placePort(&world, at: TileCoordinate(x: 5, y: 1))
    // Place a road tile on a land-face neighbor.
    world.pendingCommands.append(.place(.road, at: TileCoordinate(x: 4, y: 1)))
    _ = world.tick()
    let port = try #require(world.buildings[portID])
    #expect(world.isRoadConnected(building: port))
}

// MARK: - Demolition cascade

@Test("scenario: demolishing port breaks dependent routes")
func scenarioDemolishingPortBreaksDependentRoutes() throws {
    var world = shoreWorld(width: 12, height: 12)
    let portA = placePort(&world, at: TileCoordinate(x: 5, y: 1))
    let portB = placePort(&world, at: TileCoordinate(x: 5, y: 5))
    let routeID = EntityID(raw: 7000)
    world.routes[routeID] = Route(
        id: routeID,
        waypoints: [.port(id: portA), .port(id: portB)],
        manifest: [:],
        speed: Fixed(raw: 410),
        state: .active
    )
    let shipID = EntityID(raw: 7100)
    world.ships[shipID] = Ship(
        id: shipID, position: .zero, heading: .zero,
        routeID: routeID, waypointIdx: 0, cargo: [:],
        state: .sailing, shipClass: .default
    )
    world.pendingCommands.append(.demolish(at: TileCoordinate(x: 5, y: 1)))
    _ = world.tick()
    let route = try #require(world.routes[routeID])
    if case let .broken(.unknownPort(id)) = route.state {
        #expect(id == portA)
    } else {
        Issue.record("expected route to be broken(unknownPort(\(portA))), got \(route.state)")
    }
    #expect(world.ships[shipID]?.state == .returning)
}

@Test("scenario: demolishing shipyard does not affect existing ships")
func scenarioDemolishingShipyardDoesNotAffectExistingShips() {
    var world = shoreWorld()
    let shipyardID = placeShipyard(&world, at: TileCoordinate(x: 5, y: 1))
    let shipID = EntityID(raw: 7200)
    world.ships[shipID] = Ship(
        id: shipID, position: .zero, heading: .zero,
        routeID: nil, waypointIdx: 0, cargo: [:],
        state: .idle, shipClass: .default
    )
    world.pendingCommands.append(.demolish(at: TileCoordinate(x: 5, y: 1)))
    _ = world.tick()
    #expect(world.buildings[shipyardID] == nil)
    #expect(world.ships[shipID]?.state == .idle)
}

// MARK: - Shipyard recipe gate

@Test("scenario: shipyard requires inputs before producing")
func scenarioShipyardRequiresInputsBeforeProducing() {
    var world = shoreWorld()
    let shipyardID = placeShipyard(&world, at: TileCoordinate(x: 5, y: 1))
    // Recipe demands 20 wood + 10 planks; supply only 10 wood + 10 planks.
    if var stockpile = world.stockpiles[shipyardID] {
        _ = stockpile.deposit(.wood, amount: 10)
        _ = stockpile.deposit(.planks, amount: 10)
        world.stockpiles[shipyardID] = stockpile
    }
    let countBefore = world.ships.count
    // Fast-forward enough ticks that production would have completed
    // had the inputs been adequate. The recipe should NOT consume the
    // partial inputs and MUST NOT emit a ship.
    for _ in 0 ..< 300 {
        _ = world.tick()
    }
    #expect(world.ships.count == countBefore)
    #expect((world.stockpiles[shipyardID]?.quantity(of: .wood) ?? 0) >= 10)
}

// MARK: - Newly emitted ship defaults

@Test("scenario: newly built ship has default capacity")
func scenarioNewlyBuiltShipHasDefaultCapacity() throws {
    var world = shoreWorld()
    let shipyardID = placeShipyard(&world, at: TileCoordinate(x: 5, y: 1))
    let emitted = world.emitShip(fromShipyard: shipyardID)
    let shipID = try #require(emitted)
    let ship = try #require(world.ships[shipID])
    #expect(ship.shipClass.capacity == ShipClass.default.capacity)
    #expect(ship.shipClass.baseSpeed == ShipClass.default.baseSpeed)
}

@Test("scenario: newly built ship is idle and unassigned")
func scenarioNewlyBuiltShipIsIdleAndUnassigned() throws {
    var world = shoreWorld()
    let shipyardID = placeShipyard(&world, at: TileCoordinate(x: 5, y: 1))
    let emitted = world.emitShip(fromShipyard: shipyardID)
    let shipID = try #require(emitted)
    let ship = try #require(world.ships[shipID])
    #expect(ship.state == .idle)
    #expect(ship.routeID == nil)
    #expect(ship.cargo.isEmpty)
}

// MARK: - Goods-buffer deterministic tie-break

@Test("scenario: deterministic tie-break by entity id")
func scenarioDeterministicTieBreakByEntityId() throws {
    var world = shoreWorld(width: 12, height: 12)
    let portA = placePort(&world, at: TileCoordinate(x: 5, y: 1))
    let portB = placePort(&world, at: TileCoordinate(x: 5, y: 5))
    // Both ports are equally suitable goods buffers; the abstraction
    // resolves ties by ascending EntityID.
    let buffers = world.goodsBuffers().map(\.id)
    #expect(buffers.contains(portA))
    #expect(buffers.contains(portB))
    let portAIdx = try #require(buffers.firstIndex(of: portA))
    let portBIdx = try #require(buffers.firstIndex(of: portB))
    #expect(portA.raw < portB.raw && portAIdx < portBIdx)
}
