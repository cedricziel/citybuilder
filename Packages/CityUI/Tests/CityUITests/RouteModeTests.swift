import Foundation
import Testing
@testable import CityCore
@testable import CityUI

// platform-shells and rendering-2_5d scenarios of
// openspec/changes/add-route-authoring-ui (M2): route mode, route list,
// ship assignment, the manifest editor and the session's route overlay.

/// A Normal archipelago whose top-left corner is open water holding the
/// player's port (anchor (3, 4), docking at (3, 8)) and rival 1's port
/// (anchor (12, 4), docking at (12, 8), holding 42 wood). Tile (8, 2) is
/// a lone grass tile for land taps.
@MainActor
private struct RouteFixture {
    let session: GameSession
    let playerPort: EntityID
    let rivalPort: EntityID
    let rivalName: String

    static let land = TileCoordinate(x: 8, y: 2)
    static let water = TileCoordinate(x: 8, y: 8)

    /// `routes` gets the player's and the rival's port IDs.
    init(ships: [Ship] = [], routes: (_ player: EntityID, _ rival: EntityID) -> [Route] = { _, _ in [] }) throws {
        var world = World.newGame(layout: .archipelago, seed: 0, difficulty: .normal)
        for tileY in 0 ..< 12 {
            for tileX in 0 ..< 20 {
                world.terrainGrid[tileY * world.mapWidth + tileX] = .water
            }
        }
        for tile in [TileCoordinate(x: 3, y: 4), TileCoordinate(x: 12, y: 4), Self.land] {
            world.terrainGrid[tile.y * world.mapWidth + tile.x] = .grass
        }
        let rival = try #require(world.rival(1))
        world.stockpiles[rival.townCenterID] = Stockpile(capacity: 40)
        playerPort = Self.addPort(owner: .player, anchor: TileCoordinate(x: 3, y: 4), to: &world)
        rivalPort = Self.addPort(owner: rival.owner, anchor: TileCoordinate(x: 12, y: 4), to: &world)
        var pile = Stockpile(capacity: 200)
        pile.deposit(.wood, amount: 42)
        world.stockpiles[rivalPort] = pile
        for ship in ships {
            world.ships[ship.id] = ship
        }
        for route in routes(playerPort, rivalPort) {
            world.routes[route.id] = route
        }
        rivalName = rival.name
        session = GameSession(world: world)
    }

    private static func addPort(owner: Owner, anchor: TileCoordinate, to world: inout World) -> EntityID {
        let id = EntityID(raw: world.nextEntityRaw)
        world.nextEntityRaw &+= 1
        let dock = TileCoordinate(x: anchor.x, y: anchor.y + 4)
        world.buildings[id] = Building(
            id: id, kind: .port, anchor: anchor, state: .operational,
            landFaceTiles: [anchor], seaFaceTiles: [dock], shipAnchor: dock, owner: owner
        )
        for tile in BuildingCatalog.spec(for: .port).footprint.tiles(anchor: anchor) {
            world.occupiedTiles[tile] = id
        }
        world.stockpiles[id] = Stockpile(capacity: 200)
        return id
    }

    var authoring: RouteAuthoringViewModel? {
        session.routeAuthoring
    }
}

private func ship(_ raw: UInt32, state: ShipState = .idle, route: EntityID? = nil) -> Ship {
    Ship(
        id: EntityID(raw: raw), position: Fixed2D(x: Fixed(10), y: Fixed(10)), heading: .zero,
        routeID: route, waypointIdx: 0, cargo: [:], state: state, shipClass: .default
    )
}

private func route(_ raw: UInt32, _ waypoints: [Waypoint], state: RouteState = .active) -> Route {
    Route(id: EntityID(raw: raw), waypoints: waypoints, manifest: [:], speed: .one, state: state)
}

/// Route 9000 straight from the player's port to the rival's.
private func directRoute(_ player: EntityID, _ rival: EntityID) -> [Route] {
    [route(9000, [.port(id: player), .port(id: rival)])]
}

// MARK: - Routes button and route list

@MainActor
@Test("scenario: routes button needs a port, ship or route")
func scenarioRoutesButtonNeedsAPortShipOrRoute() throws {
    #expect(try RouteFixture().session.showsRoutesButton)
    let empty = GameSession(world: World.fixtureWithTerrain(width: 8, height: 8, fill: .grass, seed: 1))
    #expect(!empty.showsRoutesButton)
    var shipOnly = World.fixtureWithTerrain(width: 8, height: 8, fill: .water, seed: 1)
    shipOnly.ships[EntityID(raw: 7)] = ship(7)
    #expect(GameSession(world: shipOnly).showsRoutesButton)
}

@MainActor
@Test("scenario: route list row text")
func scenarioRouteListRowText() throws {
    let raw: UInt32 = 9000
    let fixture = try RouteFixture(ships: [ship(40, state: .sailing, route: EntityID(raw: raw))]) { player, rival in
        [route(raw, [.port(id: player), .sea(position: Fixed2D(x: Fixed(8), y: Fixed(8))), .port(id: rival)])]
    }
    fixture.session.step()
    let row = try #require(fixture.session.routeList.rows.first)
    #expect(row.title == "Route 1")
    #expect(row.stops == "Your port (3, 4) → \(fixture.rivalName)'s port")
    #expect(row.status == "Active · 1 ship")
}

@MainActor
@Test("route list status counts ships and reads paused and broken")
func routeListStatusVariants() throws {
    let fixture = try RouteFixture { player, rival in
        [
            route(9000, [.port(id: player), .port(id: rival)], state: .paused),
            route(9001, [.port(id: player), .port(id: rival)], state: .broken(reason: .fewerThanTwoPorts))
        ]
    }
    fixture.session.step()
    let rows = fixture.session.routeList.rows
    #expect(rows.map(\.title) == ["Route 1", "Route 2"])
    #expect(rows.map(\.status) == ["Paused · 0 ships", "Broken · 0 ships"])
}

@MainActor
@Test("scenario: pausing from the route list")
func scenarioPausingFromTheRouteList() throws {
    let fixture = try RouteFixture(routes: directRoute)
    fixture.session.step()
    fixture.session.routeList.pause(EntityID(raw: 9000))
    #expect(fixture.session.world.pendingCommands == [.setRoutePaused(id: EntityID(raw: 9000), paused: true)])
    fixture.session.routeList.resume(EntityID(raw: 9000))
    #expect(fixture.session.world.pendingCommands.last == .setRoutePaused(id: EntityID(raw: 9000), paused: false))
}

// MARK: - Assigning a ship to a route

@MainActor
@Test("scenario: assign the first idle ship")
func scenarioAssignTheFirstIdleShip() throws {
    let routeID = EntityID(raw: 9000)
    let fixture = try RouteFixture(ships: [ship(41), ship(40)], routes: directRoute)
    fixture.session.step()
    #expect(fixture.session.routeList.idleShipCount == 2)
    #expect(fixture.session.routeList.canAssignShip)
    fixture.session.routeList.assignIdleShip(to: routeID)
    #expect(fixture.session.world.pendingCommands == [.assignShipToRoute(shipID: EntityID(raw: 40), routeID: routeID)])
}

@MainActor
@Test("scenario: no idle ship to assign")
func scenarioNoIdleShipToAssign() throws {
    let routeID = EntityID(raw: 9000)
    let fixture = try RouteFixture(ships: [ship(40, state: .sailing, route: routeID)], routes: directRoute)
    fixture.session.step()
    #expect(fixture.session.routeList.idleShipCount == 0)
    #expect(!fixture.session.routeList.canAssignShip)
    fixture.session.routeList.assignIdleShip(to: routeID)
    #expect(fixture.session.world.pendingCommands.isEmpty)
}

// MARK: - Route mode

@MainActor
@Test("scenario: world taps add stops in route mode")
func scenarioWorldTapsAddStopsInRouteMode() throws {
    let fixture = try RouteFixture()
    fixture.session.beginRouteAuthoring()
    fixture.session.handleTap(at: RouteFixture.water)
    #expect(fixture.authoring?.inProgressWaypoints == [.sea(position: Fixed2D(x: Fixed(8), y: Fixed(8)))])
    #expect(fixture.session.selectedTile == nil)
    #expect(fixture.session.world.pendingCommands.isEmpty)
}

@MainActor
@Test("entering route mode clears placement, menu, selection and tool")
func enteringRouteModeResetsInteraction() throws {
    let fixture = try RouteFixture(routes: directRoute)
    let session = fixture.session
    session.step()
    session.routeList.select(EntityID(raw: 9000))
    session.selectedTool = .place(.house)
    session.beginPendingPlacement(kind: .house, at: TileCoordinate(x: 30, y: 30))
    session.tileMenuRequest = TileMenuRequest(tile: TileCoordinate(x: 30, y: 30))
    session.beginRouteAuthoring()
    #expect(session.routeAuthoring != nil)
    #expect(session.selectedTool == .inspect)
    #expect(session.pendingPlacement == nil)
    #expect(session.tileMenuRequest == nil)
    #expect(session.routeList.selectedRouteID == nil)
}

@MainActor
@Test("scenario: route from here starts at the port")
func scenarioRouteFromHereStartsAtThePort() throws {
    let fixture = try RouteFixture()
    fixture.session.selectedTile = TileCoordinate(x: 12, y: 4)
    let port = try #require(fixture.session.inspector.routeStartPort)
    #expect(port == fixture.rivalPort)
    fixture.session.beginRouteAuthoring(from: port)
    #expect(fixture.authoring?.inProgressWaypoints == [.port(id: fixture.rivalPort)])
}

@MainActor
@Test("only a port's inspector offers route from here")
func onlyPortsOfferRouteFromHere() throws {
    let fixture = try RouteFixture()
    let townCenter = try #require(fixture.session.world.rival(1)).townCenterID
    fixture.session.selectedTile = try #require(fixture.session.world.buildings[townCenter]).anchor
    #expect(fixture.session.inspector.routeStartPort == nil)
}

@MainActor
@Test("scenario: long-press does nothing in route mode")
func scenarioLongPressDoesNothingInRouteMode() throws {
    let fixture = try RouteFixture()
    fixture.session.beginRouteAuthoring()
    fixture.session.handleLongPress(at: RouteFixture.water)
    #expect(fixture.session.tileMenuRequest == nil)
    #expect(fixture.session.selectedTile == nil)
}

@MainActor
@Test("scenario: commit message for a lone port")
func scenarioCommitMessageForALonePort() throws {
    let fixture = try RouteFixture()
    fixture.session.beginRouteAuthoring(from: fixture.playerPort)
    #expect(fixture.authoring?.message == "Tap ports and water to add stops.")
    fixture.session.commitRouteAuthoring()
    #expect(fixture.authoring?.message == "A route needs at least two ports.")
    #expect(fixture.session.world.pendingCommands.isEmpty)
}

@MainActor
@Test("a commit with a red leg explains it")
func commitMessageForARedLeg() throws {
    let fixture = try RouteFixture()
    fixture.session.beginRouteAuthoring(from: fixture.playerPort)
    fixture.session.handleTap(at: TileCoordinate(x: 8, y: 3))
    fixture.session.handleTap(at: TileCoordinate(x: 8, y: 1))
    fixture.session.handleTap(at: TileCoordinate(x: 12, y: 4))
    fixture.session.commitRouteAuthoring()
    #expect(fixture.authoring?.message == "A red leg crosses land. Add water stops around it.")
    #expect(fixture.session.world.pendingCommands.isEmpty)
}

@MainActor
@Test("scenario: land tap message")
func scenarioLandTapMessage() throws {
    let fixture = try RouteFixture()
    fixture.session.beginRouteAuthoring()
    fixture.session.handleTap(at: RouteFixture.land)
    #expect(fixture.authoring?.inProgressWaypoints.isEmpty == true)
    #expect(fixture.authoring?.message == "Ships can't stop on land.")
    fixture.session.handleTap(at: RouteFixture.water)
    #expect(fixture.authoring?.message == "Tap ports and water to add stops.")
}

@MainActor
@Test("scenario: undo removes the last stop")
func scenarioUndoRemovesTheLastStop() throws {
    let fixture = try RouteFixture()
    fixture.session.beginRouteAuthoring(from: fixture.playerPort)
    fixture.session.handleTap(at: RouteFixture.water)
    fixture.session.handleTap(at: TileCoordinate(x: 12, y: 4))
    let authoring = try #require(fixture.authoring)
    authoring.setManifest([.unloadUpTo(good: .planks, qty: 10)], forPort: fixture.rivalPort)
    authoring.removeLastWaypoint()
    #expect(authoring.inProgressWaypoints == [
        .port(id: fixture.playerPort), .sea(position: Fixed2D(x: Fixed(8), y: Fixed(8)))
    ])
    #expect(authoring.manifest[fixture.rivalPort] == nil)
}

@MainActor
@Test("undo keeps the manifest of a port that is still a stop")
func undoKeepsManifestOfRemainingPort() throws {
    let fixture = try RouteFixture()
    fixture.session.beginRouteAuthoring(from: fixture.playerPort)
    fixture.session.handleTap(at: TileCoordinate(x: 12, y: 4))
    fixture.session.handleTap(at: TileCoordinate(x: 3, y: 4))
    let authoring = try #require(fixture.authoring)
    authoring.setManifest([.loadUpTo(good: .planks, qty: 10)], forPort: fixture.playerPort)
    authoring.removeLastWaypoint()
    #expect(authoring.manifest[fixture.playerPort] == [.loadUpTo(good: .planks, qty: 10)])
    authoring.removeLastWaypoint()
    authoring.removeLastWaypoint()
    authoring.removeLastWaypoint()
    #expect(authoring.inProgressWaypoints.isEmpty)
    #expect(authoring.manifest.isEmpty)
}

@MainActor
@Test("scenario: commit leaves route mode")
func scenarioCommitLeavesRouteMode() throws {
    let fixture = try RouteFixture()
    fixture.session.beginRouteAuthoring(from: fixture.playerPort)
    fixture.session.handleTap(at: TileCoordinate(x: 12, y: 4))
    fixture.session.commitRouteAuthoring()
    #expect(fixture.session.routeAuthoring == nil)
    #expect(fixture.session.world.pendingCommands == [.createRoute(
        waypoints: [.port(id: fixture.playerPort), .port(id: fixture.rivalPort)],
        manifest: [:], speed: ShipClass.default.baseSpeed
    )])
}

@MainActor
@Test("cancel leaves route mode without a command")
func cancelLeavesRouteMode() throws {
    let fixture = try RouteFixture()
    fixture.session.beginRouteAuthoring(from: fixture.playerPort)
    fixture.session.cancelRouteAuthoring()
    #expect(fixture.session.routeAuthoring == nil)
    #expect(fixture.session.world.pendingCommands.isEmpty)
}

@MainActor
@Test("stop labels name the owner")
func stopLabels() throws {
    let fixture = try RouteFixture()
    let snapshot = fixture.session.world.snapshot()
    #expect(RouteStopLabel.text(for: .port(id: fixture.playerPort), in: snapshot) == "Your port (3, 4)")
    #expect(RouteStopLabel.text(for: .port(id: fixture.rivalPort), in: snapshot) == "\(fixture.rivalName)'s port")
    #expect(RouteStopLabel.text(for: .sea(position: .zero), in: snapshot) == "Sea")
}

// MARK: - Manifest editor sheet

@Test("scenario: draft adds and removes actions")
func scenarioDraftAddsAndRemovesActions() {
    var draft = ManifestDraft(actions: [])
    draft.add(.load, good: .planks, quantity: 20)
    draft.add(.unload, good: .wood, quantity: 10)
    draft.remove(at: 0)
    #expect(draft.actions == [.unloadUpTo(good: .wood, qty: 10)])
    #expect(ManifestDraft.quantities.first == 5)
    #expect(ManifestDraft.quantities.last == 100)
    #expect(ManifestDraft.quantities.contains(ManifestDraft.defaultQuantity))
}

@MainActor
@Test("scenario: rival port actions read buy and sell")
func scenarioRivalPortActionsReadBuyAndSell() throws {
    let fixture = try RouteFixture()
    let snapshot = fixture.session.world.snapshot()
    let editor = ManifestEditorModel(snapshot: snapshot, port: fixture.rivalPort)
    #expect(editor.line(for: .loadUpTo(good: .wood, qty: 20)) == "Buy 20 Wood — $5")
    #expect(editor.line(for: .unloadUpTo(good: .tools, qty: 10)) == "Sell 10 Tools — $22")
    #expect(editor.rows(for: .load).first { $0.good == .wood }?.title == "Wood — $5 — 12")
    #expect(editor.rows(for: .load).first { $0.good == .iron }?.title == "Iron — no offer")
}

@MainActor
@Test("player port actions read load and unload")
func playerPortActionLines() throws {
    let fixture = try RouteFixture()
    let editor = ManifestEditorModel(snapshot: fixture.session.world.snapshot(), port: fixture.playerPort)
    #expect(editor.line(for: .loadUpTo(good: .wood, qty: 20)) == "Load 20 Wood")
    #expect(editor.line(for: .unloadUpTo(good: .planks, qty: 10)) == "Unload 10 Planks")
    #expect(editor.rows(for: .load).first { $0.good == .wood }?.title == "Wood")
}

@MainActor
@Test("scenario: saved manifest rides on the route")
func scenarioSavedManifestRidesOnTheRoute() throws {
    let fixture = try RouteFixture()
    fixture.session.beginRouteAuthoring(from: fixture.playerPort)
    fixture.session.handleTap(at: TileCoordinate(x: 12, y: 4))
    var draft = ManifestDraft(actions: fixture.authoring?.manifest[fixture.rivalPort] ?? [])
    draft.add(.unload, good: .planks, quantity: 10)
    fixture.authoring?.setManifest(draft.actions, forPort: fixture.rivalPort)
    fixture.session.commitRouteAuthoring()
    guard case let .createRoute(_, manifest, _) = fixture.session.world.pendingCommands.first else {
        Issue.record("expected a createRoute command")
        return
    }
    #expect(manifest[fixture.rivalPort] == [.unloadUpTo(good: .planks, qty: 10)])
}

// MARK: - Route overlay from the session

@MainActor
@Test("scenario: session overlay follows route mode and selection")
func scenarioSessionOverlayFollowsRouteModeAndSelection() throws {
    let fixture = try RouteFixture(routes: directRoute)
    let stops: [Waypoint] = [.port(id: fixture.playerPort), .port(id: fixture.rivalPort)]
    let session = fixture.session
    session.step()
    #expect(session.routeOverlay() == nil)

    session.beginRouteAuthoring()
    session.handleTap(at: TileCoordinate(x: 3, y: 4))
    session.handleTap(at: RouteFixture.water)
    let authoring = try #require(session.routeOverlay())
    #expect(authoring.waypoints == [.port(id: fixture.playerPort), .sea(position: Fixed2D(x: Fixed(8), y: Fixed(8)))])
    session.cancelRouteAuthoring()

    session.routeList.select(EntityID(raw: 9000))
    let selected = try #require(session.routeOverlay())
    #expect(selected.waypoints == stops)
    #expect(selected.redSegments.isEmpty)
    #expect(selected.flash == nil)

    session.routeList.select(nil)
    #expect(session.routeOverlay() == nil)
}

@MainActor
@Test("a rejected land tap reaches the overlay once")
func rejectedTapReachesOverlayOnce() throws {
    let fixture = try RouteFixture()
    fixture.session.beginRouteAuthoring()
    fixture.session.handleTap(at: RouteFixture.land)
    #expect(fixture.session.routeOverlay()?.flash == RouteFixture.land)
    #expect(fixture.session.routeOverlay()?.flash == nil)
}
