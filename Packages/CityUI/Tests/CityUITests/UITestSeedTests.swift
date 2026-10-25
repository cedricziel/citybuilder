import Foundation
import Testing
@testable import CityCore
@testable import CityUI

// The Debug-only seed behind `-uiTestSeedPort`, which lets the Apple TV
// walk-throughs reach Routes and the manifest editor (tasks 3.5, 3.6).

@Test("The port seed starts with Seafaring, a player port, and the camera on the port")
@MainActor
func portSeedHasAPlayerPortUnderTheCamera() throws {
    let world = UITestSeed.portWorld()
    #expect(world.research.isResearched(.seafaring))
    let port = try #require(world.buildings.values.first { $0.kind == .port && $0.owner == .player })
    #expect(world.occupiedTiles[world.camera.centerTile()] == port.id)
    #expect(GameSession(world: world).showsRoutesButton)
}

@Test("The shore seed adds a finished shipyard and a ship beside the port")
@MainActor
func shoreSeedHasAShipyardAndAShip() throws {
    let world = UITestSeed.shoreWorld()
    let shore = world.buildings.values.filter { [.port, .shipyard].contains($0.kind) && $0.owner == .player }
    #expect(Set(shore.map(\.kind)) == [.port, .shipyard])
    #expect(shore.allSatisfy { $0.state == .operational })
    #expect(world.ships.count == 1)
    let port = try #require(shore.first { $0.kind == .port })
    #expect(world.occupiedTiles[world.camera.centerTile()] == port.id)
}

@Test("The town seed has finished houses beside the town center under the default camera")
@MainActor
func townSeedHasFinishedHousesUnderTheDefaultCamera() {
    let world = UITestSeed.townWorld()
    let houses = world.buildings.values.filter { $0.kind == .house && $0.owner == .player }
    #expect(houses.count == 4)
    #expect(houses.allSatisfy { $0.state == .operational })
    #expect(world.camera == World.newGame(layout: .singleIsland, seed: 0).camera)
}

@Test("The town seed can show off a build category, for family art shots")
@MainActor
func townSeedShowsACategory() {
    let gather = UITestSeed.showcase(fromArguments: ["app", "-uiTestShowcase", "gather"])
    #expect(gather.contains(.farm) && gather.contains(.mine) && !gather.contains(.house))
    let world = UITestSeed.townWorld(showcase: gather)
    let shown = world.buildings.values.filter { gather.contains($0.kind) && $0.owner == .player }
    #expect(shown.count >= 4, "most gather kinds find a site near the town center")
    #expect(shown.allSatisfy { $0.state == .operational })
    #expect(UITestSeed.showcase(fromArguments: ["app"]).isEmpty)
    let listed = UITestSeed.showcase(fromArguments: ["app", "-uiTestShowcase", "lumberjack-hut,sawmill"])
    #expect(listed == [.lumberjackHut, .sawmill], "a list of kinds, for a working sawmill")
}

@Test("The town seed can start in a given season, for seasonal art shots")
@MainActor
func townSeedStartsInTheRequestedSeason() {
    #expect(UITestSeed.townWorld(season: .winter).date.season == .winter)
    #expect(UITestSeed.townWorld(season: .autumn).date.season == .autumn)
    #expect(UITestSeed.season(fromArguments: ["app", "-uiTestSeason", "winter"]) == .winter)
    #expect(UITestSeed.season(fromArguments: ["app"]) == nil)
}

@Test("The town seed can be built in another culture, for culture-look shots")
@MainActor
func townSeedTakesACulture() {
    #expect(UITestSeed.townWorld(culture: .mediterranean).culture == .mediterranean)
    #expect(UITestSeed.culture(fromArguments: ["app", "-uiTestCulture", "east-asian"]) == .eastAsian)
    #expect(UITestSeed.culture(fromArguments: ["app"]) == .northernEuropean)
}

@Test("The town seed stays solvent with a whole category on show")
@MainActor
func townSeedStaysSolvent() {
    var world = UITestSeed.townWorld(showcase: UITestSeed.showcase(fromArguments: ["app", "-uiTestShowcase", "town"]))
    for _ in 0 ..< 600 {
        _ = world.tick()
    }
    #expect(!world.economy.gameOver)
}

@Test("The lived seed has inhabited houses and keeps the default camera")
func livedSeedHasResidents() {
    let world = UITestSeed.livedTownWorld()
    let snapshot = world.snapshot()
    #expect(snapshot.housePopulations.values.contains { $0.population > 0 })
    #expect(world.camera == UITestSeed.townWorld().camera)
}

@Test("Launch arguments pick the seed, and no flag picks none")
func argumentsPickTheSeed() {
    #expect(UITestSeed.world(fromArguments: []) == nil)
    #expect(UITestSeed.world(fromArguments: ["-uiTestSeedTown", "-uiTestCulture", "mediterranean"])?.culture == .mediterranean)
    #expect(UITestSeed.world(fromArguments: ["-uiTestSeedTown", "-uiTestAge", "modern"])?.age == .modern)
    #expect(UITestSeed.world(fromArguments: ["-uiTestSeedShore"])?.ships.count == 1)
    #expect(UITestSeed.world(fromArguments: ["-uiTestSeedPort"])?.buildings.values.contains { $0.kind == .port } == true)
    let town = UITestSeed.world(fromArguments: ["-uiTestSeedTown", "-uiTestShowcase", "craft"])
    #expect(town?.buildings.values.contains { $0.kind == .bakery } == true)
}

@Test("The camera flag places the seeded game's camera, and odd values are ignored")
@MainActor
func cameraFlagPlacesTheSeededCamera() {
    #expect(UITestSeed.camera(fromArguments: ["-uiTestCamera", "40.5,61.5,0.5"]) == Camera(centerX: 40.5, centerY: 61.5, zoom: 0.5))
    #expect(UITestSeed.camera(fromArguments: ["-uiTestCamera", "40.5,61.5"]) == nil)
    #expect(UITestSeed.camera(fromArguments: ["-uiTestCamera"]) == nil)
    let world = UITestSeed.world(fromArguments: ["-uiTestSeedTown", "-uiTestCamera", "12,20,0.25"])
    #expect(world?.camera == Camera(centerX: 12, centerY: 20, zoom: 0.25))
}

private struct NoSaves: SaveStoreFacade {
    func mostRecentSave() throws -> SaveSummary? {
        nil
    }

    func load(gameID _: UUID) throws -> World {
        throw CocoaError(.fileNoSuchFile)
    }
}

@Test("The start-game flag skips the title, and without it the title stays")
@MainActor
func startGameFlagSkipsTheTitle() {
    let plain = TitleScreenViewModel(saveStore: NoSaves(), sessionFactory: { GameSession(world: $0) })
    plain.startGameIfRequested(arguments: ["Citybuilder"])
    #expect(plain.committedSession == nil)
    let started = TitleScreenViewModel(saveStore: NoSaves(), sessionFactory: { GameSession(world: $0) })
    started.startGameIfRequested(arguments: ["Citybuilder", "-uiTestStartGame"])
    #expect(started.committedSession != nil)
}

@Test("The open-stocks flag starts the game with the stocks tray shown")
@MainActor
func openStocksFlagShowsTheTray() {
    let plain = TitleScreenViewModel(saveStore: NoSaves(), sessionFactory: { GameSession(world: $0) })
    plain.startGameIfRequested(arguments: ["Citybuilder", "-uiTestStartGame"])
    #expect(plain.committedSession?.hud.isStocksTrayOpen == false)
    let open = TitleScreenViewModel(saveStore: NoSaves(), sessionFactory: { GameSession(world: $0) })
    open.startGameIfRequested(arguments: ["Citybuilder", "-uiTestStartGame", "-uiTestOpenStocks"])
    #expect(open.committedSession?.hud.isStocksTrayOpen == true)
}

@Test("A test or shot launch saves into a folder of its own, a regular launch into the player's")
func uiTestLaunchesKeepTheirOwnSaves() throws {
    #expect(UITestSeed.saveDirectory(fromArguments: ["Citybuilder"]) == nil)
    #expect(UITestSeed.saveDirectory(fromArguments: ["Citybuilder", "-NSDocumentRevisionsDebugMode", "YES"]) == nil)
    for flag in ["-uiTestSeedTown", "-uiTestStartGame", "-uiTestResetSaves", "-uiTestCamera"] {
        let directory = try #require(UITestSeed.saveDirectory(fromArguments: ["Citybuilder", flag]))
        #expect(directory.path.hasPrefix(FileManager.default.temporaryDirectory.path))
    }
}

@MainActor
@Test("-uiTestPlace arms a building over a tile and -uiTestSelect selects one")
func shotFlagsArmAndSelect() {
    #expect(UITestSeed.placement(fromArguments: ["-uiTestPlace", "lumberjack-hut@34,64"])?.tile == TileCoordinate(x: 34, y: 64))
    #expect(UITestSeed.placement(fromArguments: ["-uiTestPlace", "nothing@1,2"]) == nil)
    #expect(UITestSeed.selection(fromArguments: ["-uiTestSelect", "36,59"]) == TileCoordinate(x: 36, y: 59))

    let session = GameSession()
    session.confirmsBuildingPlacement = false
    session.applyTestTool(fromArguments: ["-uiTestPlace", "forester@34,64"])
    #expect(session.selectedTool == .place(.forester))
    #expect(session.hoveredTile == TileCoordinate(x: 34, y: 64))

    let touch = GameSession()
    touch.confirmsBuildingPlacement = true
    touch.applyTestTool(fromArguments: ["-uiTestPlace", "forester@34,64"])
    #expect(touch.pendingPlacement?.anchor == TileCoordinate(x: 34, y: 64))

    let inspect = GameSession()
    inspect.applyTestTool(fromArguments: ["-uiTestSelect", "36,59"])
    #expect(inspect.selectedTool == .inspect && inspect.selectedTile == TileCoordinate(x: 36, y: 59))
}

@MainActor
@Test("-uiTestPlace and -uiTestSelect ignore a tile off the map")
func shotFlagsIgnoreOffMapTiles() {
    let session = GameSession()
    session.applyTestTool(fromArguments: ["-uiTestPlace", "lumberjack-hut@500,500"])
    #expect(session.selectedTool == .inspect && session.ghostState() == nil && session.areaOfEffect() == nil)
    session.applyTestTool(fromArguments: ["-uiTestSelect", "500,500"])
    #expect(session.selectedTile == nil)
}

@Test("-uiTestSeasons runs the seeded game on, so the Statistics sheet has a history")
func seasonsFlagRunsTheSeededGameOn() {
    #expect(UITestSeed.seasons(fromArguments: []) == 0)
    #expect(UITestSeed.seasons(fromArguments: ["-uiTestSeasons"]) == 0)
    #expect(UITestSeed.seasons(fromArguments: ["-uiTestSeasons", "many"]) == 0)
    #expect(UITestSeed.seasons(fromArguments: ["-uiTestSeasons", "-3"]) == 0)
    #expect(UITestSeed.seasons(fromArguments: ["-uiTestSeasons", "99"]) == StatisticsHistory.capacity)
    let plain = UITestSeed.world(fromArguments: ["-uiTestSeedTown"])
    #expect(plain?.statistics.seasons.isEmpty == true)
    let aged = UITestSeed.world(fromArguments: ["-uiTestSeedTown", "-uiTestSeasons", "2"])
    #expect(aged?.statistics.seasons.count == 2)
}

@Test("The open-statistics flag starts the game with the Statistics sheet shown")
@MainActor
func openStatisticsFlagShowsTheSheet() {
    let plain = TitleScreenViewModel(saveStore: NoSaves(), sessionFactory: { GameSession(world: $0) })
    plain.startGameIfRequested(arguments: ["Citybuilder", "-uiTestStartGame"])
    #expect(plain.committedSession?.isStatisticsPresented == false)
    let open = TitleScreenViewModel(saveStore: NoSaves(), sessionFactory: { GameSession(world: $0) })
    open.startGameIfRequested(arguments: ["Citybuilder", "-uiTestStartGame", "-uiTestOpenStatistics"])
    #expect(open.committedSession?.isStatisticsPresented == true)
    #expect(open.committedSession?.statisticsTab == .goods)
    let money = TitleScreenViewModel(saveStore: NoSaves(), sessionFactory: { GameSession(world: $0) })
    money.startGameIfRequested(arguments: [
        "Citybuilder", "-uiTestStartGame", "-uiTestOpenStatistics", "money"
    ])
    #expect(money.committedSession?.statisticsTab == .money)
    #expect(UITestSeed.statisticsTab(fromArguments: ["-uiTestOpenStatistics", "nonsense"]) == .goods)
    #expect(UITestSeed.statisticsTab(fromArguments: ["-uiTestOpenStatistics"]) == .goods)
}

@Test("The orders seed puts two accepted orders and two offers on the board, with favour")
@MainActor
func ordersSeedHasABoard() {
    let world = UITestSeed.world(fromArguments: ["app", "-uiTestSeedOrders"])
    #expect(world?.orders.orders.map(\.state) == [.accepted, .accepted, .offered, .offered])
    #expect(world?.orders.favour.crown == 7)
    #expect(world?.orders.orders.compactMap(\.issuer.rivalID) == [1, 2])
    let board = world.map { GameSession(world: $0).ordersBoard }
    #expect(board?.cards.count == 4 && board?.acceptedCount == 2)
    #expect(board?.cards.first?.status == "In stores 38 of 54")
    #expect(UITestSeed.opensOrders(fromArguments: ["app", "-uiTestOpenOrders"]))
    #expect(!UITestSeed.opensOrders(fromArguments: ["app"]))
}

@Test("The orders seed needs no rivals to seat its offers")
@MainActor
func ordersSeedWorksWithoutRivals() {
    var world = World.newGame()
    world.seedOrdersShowcase()
    #expect(world.orders.orders.count == 4)
}
