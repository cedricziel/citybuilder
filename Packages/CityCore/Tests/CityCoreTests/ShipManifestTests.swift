import Foundation
import Testing
@testable import CityCore

// Tests for M5 ship manifest execution + shipyard production tick.
// Split from ShipTickTests.swift to stay under the 500-line lint
// ceiling.

private func shoreWorld(width: Int = 16, height: Int = 12) -> World {
    var world = World.fixtureWithTerrain(width: width, height: height, fill: .grass, seed: 11)
    for tileY in 0 ..< world.mapHeight {
        for tileX in 8 ..< world.mapWidth {
            world.terrainGrid[tileY * world.mapWidth + tileX] = .water
        }
    }
    world.economy.credit(100_000)
    world.islands = IslandDetector.detectIslands(
        width: world.mapWidth,
        height: world.mapHeight,
        terrain: world.terrainGrid,
        mapHeightForClimate: world.mapHeight,
        seed: 11
    )
    world.seedUnlimitedTestInventory()
    return world
}

private func placePort(_ world: inout World, at anchor: TileCoordinate) -> EntityID {
    world.pendingCommands.append(.place(.port, at: anchor))
    _ = world.tick()
    return world.occupiedTiles[anchor]!
}

private func makeDockedShip(
    _ world: inout World, id: UInt32, atPort portID: EntityID,
    cargo: [Good: Int] = [:]
) throws -> EntityID {
    let port = try #require(world.buildings[portID])
    let anchor = try #require(port.shipAnchor)
    let pos = Fixed2D(x: Fixed(Int32(anchor.x)), y: Fixed(Int32(anchor.y)))
    let shipID = EntityID(raw: id)
    world.ships[shipID] = Ship(
        id: shipID, position: pos, heading: .zero,
        routeID: nil, waypointIdx: 0, cargo: cargo,
        state: .docked, shipClass: .default
    )
    return shipID
}

// MARK: - Manifest actions

@Test("scenario: load action up to ship capacity")
func scenarioLoadActionUpToShipCapacity() throws {
    var world = shoreWorld()
    let portA = placePort(&world, at: TileCoordinate(x: 7, y: 1))
    let portB = placePort(&world, at: TileCoordinate(x: 7, y: 5))
    if var sp = world.stockpiles[portA] {
        _ = sp.deposit(.wood, amount: 100)
        world.stockpiles[portA] = sp
    }
    let routeID = EntityID(raw: 140)
    world.routes[routeID] = Route(
        id: routeID, waypoints: [.port(id: portA), .port(id: portB)],
        manifest: [portA: [.loadUpTo(good: .wood, qty: 50)]],
        speed: .one, state: .active
    )
    let shipID = try makeDockedShip(&world, id: 250, atPort: portA, cargo: [.planks: 80])
    world.ships[shipID]?.routeID = routeID
    _ = world.tick()
    let ship = try #require(world.ships[shipID])
    #expect(ship.cargo[.wood] == 20)
    #expect(world.stockpiles[portA]?.quantity(of: .wood) == 80)
}

@Test("scenario: load action up to port stock")
func scenarioLoadActionUpToPortStock() throws {
    var world = shoreWorld()
    let portA = placePort(&world, at: TileCoordinate(x: 7, y: 1))
    let portB = placePort(&world, at: TileCoordinate(x: 7, y: 5))
    if var sp = world.stockpiles[portA] {
        _ = sp.deposit(.wood, amount: 30)
        world.stockpiles[portA] = sp
    }
    let routeID = EntityID(raw: 141)
    world.routes[routeID] = Route(
        id: routeID, waypoints: [.port(id: portA), .port(id: portB)],
        manifest: [portA: [.loadUpTo(good: .wood, qty: 50)]],
        speed: .one, state: .active
    )
    let shipID = try makeDockedShip(&world, id: 251, atPort: portA)
    world.ships[shipID]?.routeID = routeID
    _ = world.tick()
    let ship = try #require(world.ships[shipID])
    #expect(ship.cargo[.wood] == 30)
    #expect(world.stockpiles[portA]?.quantity(of: .wood) == 0)
}

@Test("scenario: unload action up to port free capacity")
func scenarioUnloadActionUpToPortFreeCapacity() throws {
    var world = shoreWorld()
    let portA = placePort(&world, at: TileCoordinate(x: 7, y: 1))
    let portB = placePort(&world, at: TileCoordinate(x: 7, y: 5))
    if var sp = world.stockpiles[portA] {
        _ = sp.deposit(.wood, amount: 175)
        world.stockpiles[portA] = sp
    }
    let routeID = EntityID(raw: 142)
    world.routes[routeID] = Route(
        id: routeID, waypoints: [.port(id: portA), .port(id: portB)],
        manifest: [portA: [.unloadUpTo(good: .wood, qty: 50)]],
        speed: .one, state: .active
    )
    let shipID = try makeDockedShip(&world, id: 252, atPort: portA, cargo: [.wood: 40])
    world.ships[shipID]?.routeID = routeID
    _ = world.tick()
    let ship = try #require(world.ships[shipID])
    #expect(ship.cargo[.wood] == 15)
    #expect(world.stockpiles[portA]?.quantity(of: .wood) == 200)
}

@Test("scenario: manifest actions execute in declared order")
func scenarioManifestActionsExecuteInDeclaredOrder() throws {
    var world = shoreWorld()
    let portA = placePort(&world, at: TileCoordinate(x: 7, y: 1))
    let portB = placePort(&world, at: TileCoordinate(x: 7, y: 5))
    if var sp = world.stockpiles[portA] {
        _ = sp.deposit(.wood, amount: 100)
        world.stockpiles[portA] = sp
    }
    let routeID = EntityID(raw: 143)
    world.routes[routeID] = Route(
        id: routeID, waypoints: [.port(id: portA), .port(id: portB)],
        manifest: [portA: [
            .unloadUpTo(good: .planks, qty: 50),
            .loadUpTo(good: .wood, qty: 50)
        ]],
        speed: .one, state: .active
    )
    let shipID = try makeDockedShip(&world, id: 253, atPort: portA, cargo: [.planks: 100])
    world.ships[shipID]?.routeID = routeID
    _ = world.tick()
    let ship = try #require(world.ships[shipID])
    #expect(ship.cargo[.planks] == 50)
    #expect(ship.cargo[.wood] == 50)
    #expect(world.stockpiles[portA]?.quantity(of: .planks) == 50)
    #expect(world.stockpiles[portA]?.quantity(of: .wood) == 50)
}

// MARK: - Integration is Fixed-only

@Test("scenario: integration uses only fixed arithmetic")
func scenarioIntegrationUsesOnlyFixedArithmetic() throws {
    let path = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Sources/CityCore/Systems/ShipTick.swift").path
    let source = try String(contentsOfFile: path, encoding: .utf8)
    let codeLines = source.split(separator: "\n", omittingEmptySubsequences: false)
        .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
        .joined(separator: "\n")
    #expect(!codeLines.contains(" Float "))
    #expect(!codeLines.contains(": Float"))
    #expect(!codeLines.contains(" Double "))
    #expect(!codeLines.contains(": Double"))
    #expect(!codeLines.contains(" CGFloat"))
}

// MARK: - Buffer capacity (sea-side)

@Test("scenario: ship deposits into port from sea")
func scenarioShipDepositsIntoPortFromSea() throws {
    var world = shoreWorld()
    let portA = placePort(&world, at: TileCoordinate(x: 7, y: 1))
    let portB = placePort(&world, at: TileCoordinate(x: 7, y: 5))
    let routeID = EntityID(raw: 144)
    world.routes[routeID] = Route(
        id: routeID, waypoints: [.port(id: portA), .port(id: portB)],
        manifest: [portA: [.unloadUpTo(good: .wood, qty: 10)]],
        speed: .one, state: .active
    )
    let shipID = try makeDockedShip(&world, id: 260, atPort: portA, cargo: [.wood: 10])
    world.ships[shipID]?.routeID = routeID
    _ = world.tick()
    let ship = try #require(world.ships[shipID])
    #expect((ship.cargo[.wood] ?? 0) == 0)
    #expect(world.stockpiles[portA]?.quantity(of: .wood) == 10)
}

@Test("scenario: port respects buffer capacity on sea-side deposit")
func scenarioPortRespectsBufferCapacityOnSeaSideDeposit() throws {
    var world = shoreWorld()
    let portA = placePort(&world, at: TileCoordinate(x: 7, y: 1))
    let portB = placePort(&world, at: TileCoordinate(x: 7, y: 5))
    if var sp = world.stockpiles[portA] {
        _ = sp.deposit(.wood, amount: 190)
        world.stockpiles[portA] = sp
    }
    let routeID = EntityID(raw: 145)
    world.routes[routeID] = Route(
        id: routeID, waypoints: [.port(id: portA), .port(id: portB)],
        manifest: [portA: [.unloadUpTo(good: .wood, qty: 50)]],
        speed: .one, state: .active
    )
    let shipID = try makeDockedShip(&world, id: 261, atPort: portA, cargo: [.wood: 50])
    world.ships[shipID]?.routeID = routeID
    _ = world.tick()
    let ship = try #require(world.ships[shipID])
    #expect(ship.cargo[.wood] == 40)
    #expect(world.stockpiles[portA]?.quantity(of: .wood) == 200)
}

// MARK: - Shipyard production tick

@Test("scenario: shipyard emits ship on recipe completion")
func scenarioShipyardEmitsShipOnRecipeCompletion() throws {
    var world = shoreWorld(width: 16, height: 14)
    world.pendingCommands.append(.place(.shipyard, at: TileCoordinate(x: 7, y: 1)))
    _ = world.tick()
    let shipyardID = try #require(world.occupiedTiles[TileCoordinate(x: 7, y: 1)])
    world.buildings[shipyardID]?.state = .operational
    if var sp = world.stockpiles[shipyardID] {
        _ = sp.deposit(.wood, amount: 20)
        _ = sp.deposit(.planks, amount: 10)
        world.stockpiles[shipyardID] = sp
    }
    let recipe = try #require(ProductionCatalog.recipe(for: .shipyard))
    let countBefore = world.ships.count
    for _ in 0 ... recipe.cycleTicks {
        _ = world.tick()
    }
    #expect(world.ships.count == countBefore + 1)
    #expect((world.stockpiles[shipyardID]?.quantity(of: .wood) ?? 0) == 0)
    #expect((world.stockpiles[shipyardID]?.quantity(of: .planks) ?? 0) == 0)
}

@Test("scenario: shipyard emits at most one ship per recipe cycle")
func scenarioShipyardEmitsAtMostOneShipPerRecipeCycle() throws {
    var world = shoreWorld(width: 16, height: 14)
    world.pendingCommands.append(.place(.shipyard, at: TileCoordinate(x: 7, y: 1)))
    _ = world.tick()
    let shipyardID = try #require(world.occupiedTiles[TileCoordinate(x: 7, y: 1)])
    world.buildings[shipyardID]?.state = .operational
    if var sp = world.stockpiles[shipyardID] {
        _ = sp.deposit(.wood, amount: 40)
        _ = sp.deposit(.planks, amount: 20)
        world.stockpiles[shipyardID] = sp
    }
    let recipe = try #require(ProductionCatalog.recipe(for: .shipyard))
    let countBefore = world.ships.count
    for _ in 0 ... recipe.cycleTicks {
        _ = world.tick()
    }
    #expect(world.ships.count == countBefore + 1)
}
