import Foundation
import Testing
@testable import CityCore
@testable import CityUI

// platform-shells scenarios of openspec/changes/add-rival-towns (M5).

/// A Hard archipelago with rival 1 renamed Ravenshore. The player is
/// Northern European, so rival 1 is Mediterranean.
private func ravenshoreWorld(treasury: Int64 = 1400) -> World {
    var world = World.newGame(layout: .archipelago, seed: 0, culture: .northernEuropean, difficulty: .hard)
    let first = world.rivals[0]
    world.rivals[0] = RivalTown(
        id: first.id, name: "Ravenshore", islandID: first.islandID, culture: first.culture,
        colour: first.colour, age: first.age, treasury: treasury, townCenterID: first.townCenterID, ai: first.ai
    )
    return world
}

/// A peasants' house of rival 1, by default next to its town center.
@discardableResult
private func rivalHouse(in world: inout World, residents: UInt32, at tile: TileCoordinate? = nil) -> TileCoordinate {
    let center = world.buildings[world.rivals[0].townCenterID]!.anchor
    let anchor = tile ?? TileCoordinate(x: center.x + 4, y: center.y)
    let id = EntityID(raw: world.nextEntityRaw)
    world.nextEntityRaw &+= 1
    world.buildings[id] = Building(id: id, kind: .house, anchor: anchor, state: .operational, owner: .rival(1))
    for tile in Footprint(width: 2, height: 2).tiles(anchor: anchor) {
        world.occupiedTiles[tile] = id
    }
    var pop = HousePopulation()
    pop.population = residents
    world.populations[id] = pop
    return anchor
}

// MARK: - New Game offers rival towns

@MainActor
@Test("scenario: toggle reaches the world")
func scenarioToggleReachesTheWorld() throws {
    let dialog = NewGameDialogViewModel()
    dialog.layout = .archipelago
    dialog.difficulty = .normal
    #expect(dialog.showsRivalToggle)
    #expect(dialog.rivalTowns)
    dialog.rivalTowns = false
    let world = try #require(dialog.commit())
    #expect(world.rivals.isEmpty)
    dialog.rivalTowns = true
    #expect(try #require(dialog.commit()).rivals.count == 2)
}

@MainActor
@Test("scenario: island rivalry locks the layout")
func scenarioIslandRivalryLocksTheLayout() {
    let dialog = NewGameDialogViewModel()
    dialog.mode = .scenario
    #expect(dialog.layout == .singleIsland)
    #expect(!dialog.isLayoutLocked)
    dialog.scenario = .islandRivalry
    #expect(dialog.layout == .archipelago)
    #expect(dialog.isLayoutLocked)
    #expect(!dialog.showsRivalToggle)
}

// MARK: - Standings panel

@Test("scenario: standings row text")
func scenarioStandingsRowText() throws {
    var world = ravenshoreWorld(treasury: 1234)
    for index in 0 ..< 13 {
        rivalHouse(in: &world, residents: 4, at: TileCoordinate(x: -10, y: -10 - 3 * index))
    }
    let rows = StandingsPanelModel(world: world, locale: Locale(identifier: "en_US")).rows
    let row = try #require(rows.first)
    #expect(row.name == "Ravenshore")
    #expect(row.population == "52")
    #expect(row.age == "Medieval")
    #expect(row.wealth == "$1,234")
    #expect(!row.isPlayer)
    #expect(rows.contains { $0.isPlayer && $0.name == "You" })
}

@Test("scenario: hidden without rivals")
func scenarioHiddenWithoutRivals() {
    #expect(!StandingsPanelModel.isAvailable(in: World.newGame(layout: .singleIsland, seed: 0, difficulty: .hard)))
    #expect(StandingsPanelModel.isAvailable(in: ravenshoreWorld()))
}

// MARK: - Rival islands and buildings in the UI

@MainActor
@Test("scenario: foreign island text")
func scenarioForeignIslandText() throws {
    let world = ravenshoreWorld()
    let center = try #require(world.buildings[world.rivals[0].townCenterID]).anchor
    let tile = TileCoordinate(x: center.x + 4, y: center.y)
    #expect(world.canPlace(.house, at: tile) == .rejected(.foreignIsland(.rival(1))))
    let session = GameSession(world: world)
    session.selectTool(.place(.house))
    session.handleTap(at: tile)
    #expect(session.hud.rejectionMessage(at: Date()) == "Ravenshore's island — you can't build here.")
}

@MainActor
@Test("scenario: rival inspector")
func scenarioRivalInspector() {
    var world = ravenshoreWorld()
    let tile = rivalHouse(in: &world, residents: 3)
    let inspector = InspectorViewModel.make(from: world.snapshot(), tile: tile, buildings: world.buildings)
    #expect(inspector.rival?.name == "Ravenshore")
    #expect(inspector.rival?.colour == .crimson)
    #expect(inspector.bullets.contains("Tier: Plebeians"))
    let menu = TileMenuViewModel(tile: tile, world: world, money: 10000)
    #expect(!menu.items.contains(.demolish))
}

@Test("scenario: rival island overlay")
func scenarioRivalIslandOverlay() throws {
    var world = ravenshoreWorld()
    let island = try #require(world.islands.first { $0.id == world.rivals[0].islandID })
    world.camera = Camera(
        centerX: Double(island.bounds.minX + island.bounds.maxX) / 2,
        centerY: Double(island.bounds.minY + island.bounds.maxY) / 2,
        zoom: 1
    )
    let hud = HUDViewModel()
    hud.apply(world.snapshot())
    #expect(hud.currentIslandName == "Ravenshore (rival)")
    #expect(hud.stocksRow.isEmpty)
}

@MainActor
@Test("scenario: rival age banner")
func scenarioRivalAgeBanner() {
    let session = GameSession(world: ravenshoreWorld())
    session.noteBannerEvents(in: [.rivalAgeAdvanced(1, .renaissance)])
    #expect(session.banner?.title == "Ravenshore enters the Renaissance")
}
