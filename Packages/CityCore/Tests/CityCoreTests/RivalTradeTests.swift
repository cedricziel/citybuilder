import Foundation
import Testing
@testable import CityCore

// rival-trade and sea-transport scenarios (openspec/changes/add-rival-trade,
// M2): trading by ship at a rival port.

// MARK: - Trading at a rival port

@Test("scenario: buying wood")
func scenarioBuyingWood() {
    var fixture = TradeFixture()
    fixture.setStock([.wood: 42])
    fixture.world.economy.balance = 1000
    let ship = fixture.dockShip(at: fixture.rivalPort, actions: [.loadUpTo(good: .wood, qty: 20)])
    let events = fixture.dock()
    #expect(fixture.world.ships[ship]?.cargo[.wood] == 12)
    #expect(fixture.world.economy.balance == 940)
    #expect(fixture.treasury == 1060)
    #expect(fixture.world.rivalStock(1)[.wood] == 30)
    #expect(events == [.tradeCompleted(rival: 1, good: .wood, quantity: 12, total: 60, direction: .bought)])
}

@Test("scenario: selling tools")
func scenarioSellingTools() {
    var fixture = TradeFixture()
    fixture.setStock([.food: 15], in: fixture.townCenter)
    fixture.world.economy.balance = 1000
    let ship = fixture.dockShip(at: fixture.rivalPort, actions: [.unloadUpTo(good: .tools, qty: 30)], cargo: [.tools: 30])
    let events = fixture.dock()
    #expect(fixture.world.stockpiles[fixture.townCenter]?.quantity(of: .tools) == 20)
    #expect(fixture.world.ships[ship]?.cargo[.tools] == 10)
    #expect(fixture.world.economy.balance == 1440)
    #expect(fixture.treasury == 560)
    #expect(events == [.tradeCompleted(rival: 1, good: .tools, quantity: 20, total: 440, direction: .sold)])
}

@Test("scenario: rival can't pay")
func scenarioRivalCantPay() {
    var fixture = TradeFixture(treasury: 30)
    let ship = fixture.dockShip(at: fixture.rivalPort, actions: [.unloadUpTo(good: .tools, qty: 5)], cargo: [.tools: 5])
    let balance = fixture.world.economy.balance
    _ = fixture.dock()
    #expect(fixture.world.ships[ship]?.cargo[.tools] == 4)
    #expect(fixture.world.economy.balance == balance + 22)
    #expect(fixture.treasury == 8)
}

@Test("scenario: nothing to buy waits")
func scenarioNothingToBuyWaits() throws {
    var fixture = TradeFixture()
    let shipID = fixture.dockShip(at: fixture.rivalPort, actions: [.loadUpTo(good: .iron, qty: 10)])
    let balance = fixture.world.economy.balance
    let events = fixture.dock()
    let ship = try #require(fixture.world.ships[shipID])
    #expect(events.isEmpty)
    #expect(ship.cargo.isEmpty)
    #expect(ship.state == .docked)
    #expect(ship.dockedManifestIndex == 0)
    #expect(ship.dockedTicksWaited == 1)
    #expect(fixture.world.economy.balance == balance)
    #expect(fixture.treasury == 1000)
}

@Test("a purchase stops at what the player's balance pays for")
func purchaseLimitedByBalance() {
    var fixture = TradeFixture()
    fixture.setStock([.wood: 60])
    fixture.world.economy.balance = 26
    let ship = fixture.dockShip(at: fixture.rivalPort, actions: [.loadUpTo(good: .wood, qty: 20)])
    _ = fixture.dock()
    #expect(fixture.world.ships[ship]?.cargo[.wood] == 5)
    #expect(fixture.world.economy.balance == 1)
    fixture.world.economy.balance = -10
    _ = fixture.dock()
    #expect(fixture.world.ships[ship]?.cargo[.wood] == 5)
}

@Test("purchases leave the rival's buffers in ID order")
func purchasesWithdrawInIDOrder() {
    var fixture = TradeFixture()
    fixture.setStock([.wood: 25], in: fixture.townCenter)
    fixture.setStock([.wood: 25])
    _ = fixture.dockShip(at: fixture.rivalPort, actions: [.loadUpTo(good: .wood, qty: 20)])
    _ = fixture.dock()
    #expect(fixture.world.stockpiles[fixture.townCenter]?.quantity(of: .wood) == 5)
    #expect(fixture.world.stockpiles[fixture.warehouse]?.quantity(of: .wood) == 25)
}

@Test("a sale stops at the free space of the rival's buffers, filling the town center first")
func saleLimitedByFreeSpace() {
    var fixture = TradeFixture()
    fixture.setStock([.food: 38], in: fixture.townCenter)
    fixture.setStock([.grain: 197])
    fixture.setStock([.ore: 199], in: fixture.rivalPort)
    let ship = fixture.dockShip(at: fixture.rivalPort, actions: [.unloadUpTo(good: .tools, qty: 30)], cargo: [.tools: 30])
    _ = fixture.dock()
    #expect(fixture.world.ships[ship]?.cargo[.tools] == 24)
    #expect(fixture.world.stockpiles[fixture.townCenter]?.quantity(of: .tools) == 2)
    #expect(fixture.world.stockpiles[fixture.warehouse]?.quantity(of: .tools) == 3)
    #expect(fixture.world.stockpiles[fixture.rivalPort]?.quantity(of: .tools) == 1)
}

@Test("no trade moves anything after game over")
func noTradeAfterGameOver() {
    var fixture = TradeFixture()
    fixture.setStock([.wood: 42])
    fixture.world.economy.gameOver = true
    let ship = fixture.dockShip(at: fixture.rivalPort, actions: [.loadUpTo(good: .wood, qty: 20)])
    #expect(fixture.dock().isEmpty)
    #expect(fixture.world.ships[ship]?.cargo.isEmpty == true)
}

// MARK: - Routes may stop at rival ports

@Test("scenario: route to a rival port is valid")
func scenarioRouteToARivalPortIsValid() {
    var fixture = TradeFixture()
    let waypoints: [Waypoint] = [.port(id: fixture.playerPort), .port(id: fixture.rivalPort)]
    fixture.world.enqueue(.createRoute(waypoints: waypoints, manifest: [:], speed: ShipClass.default.baseSpeed))
    fixture.world.tick()
    #expect(fixture.world.routes.values.contains { $0.waypoints == waypoints && $0.state == .active })
}

@Test("scenario: player port unchanged")
func scenarioPlayerPortUnchanged() {
    var fixture = TradeFixture()
    let balance = fixture.world.economy.balance
    _ = fixture.dockShip(at: fixture.playerPort, actions: [.unloadUpTo(good: .planks, qty: 10)], cargo: [.planks: 10])
    let events = fixture.dock()
    #expect(fixture.world.stockpiles[fixture.playerPort]?.quantity(of: .planks) == 10)
    #expect(fixture.world.economy.balance == balance)
    #expect(events.isEmpty)
}

// MARK: - Determinism

/// A 2×3 shore spot on `islandID` whose anchor tile is land.
private func shoreAnchor(onIsland islandID: IslandID, in world: World) -> TileCoordinate? {
    world.testFirstTile(onIsland: islandID) { anchor in
        let tiles = BuildingCatalog.spec(for: .port).footprint.tiles(anchor: anchor)
        return tiles.allSatisfy { world.contains($0) && world.occupiedTiles[$0] == nil }
            && tiles.contains { world.terrain(at: $0) == .water }
    }
}

/// A Hard archipelago with a player ship carrying planks from the
/// player's port to rival 1's port and buying wood there.
private func tradingWorld() throws -> World {
    var world = World.newGame(layout: .archipelago, seed: 42, difficulty: .hard)
    let map = world.tileToIslandMap()
    let home = try #require(map[TileCoordinate(x: world.mapWidth / 2, y: world.mapHeight / 2)])
    let rival = try #require(world.rival(1))
    let playerPort = try world.testPlace(.port, at: #require(shoreAnchor(onIsland: home, in: world)), owner: .player)
    let rivalPort = try world.testPlace(.port, at: #require(shoreAnchor(onIsland: rival.islandID, in: world)), owner: rival.owner)
    world.stockpiles[playerPort]?.deposit(.planks, amount: 200)
    let routeID = EntityID(raw: world.nextEntityRaw)
    let shipID = EntityID(raw: world.nextEntityRaw + 1)
    world.nextEntityRaw &+= 2
    world.routes[routeID] = Route(
        id: routeID, waypoints: [.port(id: playerPort), .port(id: rivalPort)],
        manifest: [
            playerPort: [.loadUpTo(good: .planks, qty: 40)],
            rivalPort: [.unloadUpTo(good: .planks, qty: 40), .loadUpTo(good: .wood, qty: 20)]
        ],
        speed: ShipClass.default.baseSpeed, state: .active
    )
    let start = world.shipTargetPosition(for: .port(id: playerPort))
    world.ships[shipID] = Ship(
        id: shipID, position: start, heading: .zero, routeID: routeID, waypointIdx: 0,
        cargo: [:], state: .sailing, shipClass: .default
    )
    return world
}

@Test("two worlds with a player route to a rival port stay equal")
func tradeRouteReplaysIdentically() throws {
    var first = try tradingWorld()
    var second = try tradingWorld()
    let firstEvents = first.testRun(ticks: 3000)
    let secondEvents = second.testRun(ticks: 3000)
    #expect(first == second)
    #expect(firstEvents == secondEvents)
    #expect(firstEvents.contains { if case .tradeCompleted(1, .planks, _, _, .sold) = $0 { true } else { false } })
}
