import Testing
@testable import CityCore
@testable import CityUI

// Scenarios from openspec/changes/fix-early-game-edge-cases (platform-shells).

@MainActor
private func lostSession() -> GameSession {
    var world = World.newGame()
    world.economy.gameOver = true
    return GameSession(world: world)
}

@MainActor
@Test("scenario: bankruptcy banner stays up")
func scenarioBankruptcyBannerStaysUp() {
    let session = lostSession()
    for _ in 0 ... GameSession.bannerTicks {
        session.step()
    }
    let banner = session.banner
    #expect(banner?.title == "Bankrupt")
    #expect(banner?.description.contains("pause menu") == true)
    #expect(banner?.description.contains("title") == true)
}

@MainActor
@Test("scenario: build tools stay off after game over")
func scenarioBuildToolsStayOffAfterGameOver() throws {
    let session = lostSession()
    session.selectTool(.place(.road))
    #expect(session.selectedTool == .inspect)
    session.selectedTool = .demolish
    let center = try #require(session.world.goodsBuffers(of: .player).first).anchor
    session.handleTap(at: center)
    session.handleDrag(at: center)
    session.handleLongPress(at: center)
    #expect(session.world.pendingCommands.isEmpty)
    #expect(session.tileMenuRequest == nil)
}

@MainActor
@Test("scenario: game over disarms the armed tool")
func scenarioGameOverDisarmsTheArmedTool() throws {
    var world = World.newGame()
    world.economy.balance = -1
    world.economy.bankruptcyDeficitTicks = world.difficulty.bankruptcyGraceTicks
    let session = GameSession(world: world)
    session.confirmsBuildingPlacement = true
    session.selectTool(.place(.sawmill))
    let center = try #require(session.world.goodsBuffers(of: .player).first).anchor
    session.handleTap(at: TileCoordinate(x: center.x + 4, y: center.y + 4))
    #expect(session.pendingPlacement != nil)
    session.step()
    #expect(session.world.economy.gameOver)
    #expect(session.selectedTool == .inspect)
    #expect(session.pendingPlacement == nil)
}

@MainActor
@Test("scenario: research is off after game over")
func scenarioResearchIsOffAfterGameOver() {
    let session = lostSession()
    #expect(!session.isResearchAvailable)
    session.chooseResearch(.milling)
    #expect(session.world.pendingCommands.isEmpty)
}

@MainActor
@Test("scenario: tile menu stays shut after game over")
func scenarioTileMenuStaysShutAfterGameOver() throws {
    let session = lostSession()
    let center = try #require(session.world.goodsBuffers(of: .player).first).anchor
    session.selectedTile = center
    #expect(!session.offersTileMenu)
    session.applyMenuChoice(.build(.road), at: TileCoordinate(x: center.x + 4, y: center.y + 4))
    session.applyMenuChoice(.demolish, at: center)
    #expect(session.selectedTool == .inspect)
    #expect(session.world.pendingCommands.isEmpty)
}

@MainActor
private func lostSession(with kind: BuildingKind) -> GameSession {
    var world = World.fixtureWithTerrain(width: 40, height: 30, fill: .grass, seed: 1)
    let anchor = TileCoordinate(x: 4, y: 4)
    let id = EntityID(raw: world.nextEntityRaw)
    world.nextEntityRaw &+= 1
    world.buildings[id] = Building(id: id, kind: kind, anchor: anchor, state: .operational)
    for tile in BuildingCatalog.spec(for: kind).footprint.tiles(anchor: anchor) {
        world.occupiedTiles[tile] = id
    }
    world.economy.balance = 500
    world.economy.gameOver = true
    let session = GameSession(world: world)
    session.selectedTile = anchor
    return session
}

@MainActor
@Test("scenario: inspector and route actions are off after game over")
func scenarioInspectorAndRouteActionsAreOffAfterGameOver() {
    let gallery = lostSession(with: .gallery)
    gallery.commissionArt()
    gallery.demolishSelection()
    #expect(gallery.world.pendingCommands.isEmpty)

    let caravanserai = lostSession(with: .caravanserai)
    caravanserai.pickExport(.bread)
    #expect(caravanserai.world.pendingCommands.isEmpty)

    let port = lostSession(with: .port)
    port.beginRouteAuthoring()
    #expect(port.routeAuthoring == nil)
    port.routeList.commandSink(.setRoutePaused(id: EntityID(raw: 1), paused: true))
    #expect(port.world.pendingCommands.isEmpty)
}

@MainActor
@Test func marketTradesAreDroppedAfterGameOver() throws {
    let session = lostSession()
    let townCenter = try #require(session.world.buildings.values.first { $0.kind == .townCenter }?.id)
    session.enqueue(.marketBuy(townCenter, .wood, 5))
    session.enqueue(.marketSell(townCenter, .wood, 5))
    #expect(session.world.pendingCommands.isEmpty)
}

@MainActor
@Test("scenario: game over ends route mode")
func scenarioGameOverEndsRouteMode() {
    var world = World.newGame()
    world.economy.balance = -1
    world.economy.bankruptcyDeficitTicks = world.difficulty.bankruptcyGraceTicks
    let session = GameSession(world: world)
    session.beginRouteAuthoring()
    #expect(session.routeAuthoring != nil)
    session.step()
    #expect(session.routeAuthoring == nil)
}
