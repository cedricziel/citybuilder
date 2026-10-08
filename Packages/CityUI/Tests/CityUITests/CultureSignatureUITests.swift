import Testing
@testable import CityCore
@testable import CityUI

// Scenarios from openspec/changes/add-culture-signatures.

@discardableResult
private func inject(_ kind: BuildingKind, at anchor: TileCoordinate, in world: inout World) -> EntityID {
    let id = EntityID(raw: world.nextEntityRaw)
    world.nextEntityRaw &+= 1
    world.buildings[id] = Building(id: id, kind: kind, anchor: anchor, state: .operational)
    for tile in BuildingCatalog.spec(for: kind).footprint.tiles(anchor: anchor) {
        world.occupiedTiles[tile] = id
    }
    if let capacity = World.stockpileCapacity(for: kind) {
        world.stockpiles[id] = Stockpile(capacity: capacity)
    }
    return id
}

private func grass() -> World {
    World.fixtureWithTerrain(width: 40, height: 30, fill: .grass, seed: 1)
}

@discardableResult
private func house(_ tier: HouseTier, residents: UInt32, at anchor: TileCoordinate, in world: inout World) -> EntityID {
    let id = inject(.house, at: anchor, in: &world)
    var pop = HousePopulation()
    pop.tier = tier
    pop.population = residents
    world.populations[id] = pop
    return id
}

@MainActor
private func lines(at tile: TileCoordinate, in session: GameSession) -> [String] {
    session.selectedTile = tile
    return session.inspector.bullets
}

// MARK: - Caravanserai

@MainActor
@Test("scenario: picking an export")
func scenarioPickingAnExport() throws {
    var world = grass()
    let caravanserai = inject(.caravanserai, at: TileCoordinate(x: 4, y: 4), in: &world)
    let session = GameSession(world: world)
    session.selectedTile = TileCoordinate(x: 4, y: 4)
    let picker = try #require(session.inspector.exportPicker)
    #expect(picker.options.first == .some(nil))
    #expect(picker.options.dropFirst().map(\.self) == Good.allCases.filter { $0 != .coffee })
    #expect(picker.selected == nil)
    session.pickExport(.bread)
    #expect(session.world.pendingCommands.contains(.setExport(caravanserai, .bread)))
}

@MainActor
@Test("only caravanserais have an export picker")
func onlyCaravanseraisHaveAnExportPicker() {
    var world = grass()
    inject(.forum, at: TileCoordinate(x: 4, y: 4), in: &world)
    let session = GameSession(world: world)
    session.selectedTile = TileCoordinate(x: 4, y: 4)
    #expect(session.inspector.exportPicker == nil)
}

@MainActor
@Test("scenario: last caravan line")
func scenarioLastCaravanLine() {
    var world = grass()
    let caravanserai = inject(.caravanserai, at: TileCoordinate(x: 4, y: 4), in: &world)
    world.buildings[caravanserai]?.lastCaravan = CaravanSale(goods: [.bread: 4], revenue: 48)
    let session = GameSession(world: world)
    let bullets = lines(at: TileCoordinate(x: 4, y: 4), in: session)
    #expect(bullets.contains("Last caravan: 4 bread for $48"))
    #expect(bullets.contains("Next caravan in 0:10"))
    #expect(bullets.contains("No coffee"))
    session.world.buildings[caravanserai]?.fuelled = true
    session.world.buildings[caravanserai]?.lastCaravan = CaravanSale(goods: [.tools: 1, .bread: 3], revenue: 66)
    let served = lines(at: TileCoordinate(x: 4, y: 4), in: session)
    #expect(served.contains("Serving coffee"))
    #expect(served.contains("Last caravan: 3 bread and 1 tools for $66"))
}

// MARK: - Ranged signatures

@MainActor
@Test("culture signature inspector lines")
func cultureSignatureInspectorLines() {
    var world = grass()
    let hall = inject(.meadHall, at: TileCoordinate(x: 2, y: 2), in: &world)
    inject(.sawmill, at: TileCoordinate(x: 6, y: 2), in: &world)
    inject(.bakery, at: TileCoordinate(x: 2, y: 6), in: &world)
    inject(.farm, at: TileCoordinate(x: 6, y: 6), in: &world)
    inject(.forum, at: TileCoordinate(x: 20, y: 2), in: &world)
    house(.peasants, residents: 2, at: TileCoordinate(x: 24, y: 2), in: &world)
    let temple = inject(.templeGarden, at: TileCoordinate(x: 20, y: 20), in: &world)
    house(.citizens, residents: 6, at: TileCoordinate(x: 24, y: 20), in: &world)
    house(.peasants, residents: 3, at: TileCoordinate(x: 20, y: 24), in: &world)
    let session = GameSession(world: world)
    #expect(lines(at: TileCoordinate(x: 2, y: 2), in: session).contains("Halves upkeep of 2 buildings"))
    #expect(lines(at: TileCoordinate(x: 20, y: 2), in: session).contains("+1 tax per resident in 1 house"))
    #expect(lines(at: TileCoordinate(x: 20, y: 20), in: session).contains("+1 knowledge per resident from 6 residents"))
    session.world.buildings[hall]?.fuelled = true
    session.world.buildings[temple]?.fuelled = true
    #expect(lines(at: TileCoordinate(x: 2, y: 2), in: session).contains("Serving beer: no upkeep for 2 buildings"))
    #expect(lines(at: TileCoordinate(x: 20, y: 20), in: session)
        .contains("Serving tea: +2 knowledge per resident from 6 residents"))
}

// MARK: - Banner

@MainActor
@Test("scenario: forum out of wine")
func scenarioForumOutOfWine() {
    let session = GameSession(world: grass())
    session.noteBannerEvents(in: [.fuelRanOut(building: EntityID(raw: 3), kind: .forum)])
    #expect(session.banner?.title == "Forum is out of wine")
    #expect(session.banner?.description == "Its effect halves until carriers bring more.")
    session.noteBannerEvents(in: [.fuelRanOut(building: EntityID(raw: 4), kind: .steamEngine)])
    #expect(session.banner?.title == "Steam engine is out of charcoal")
}
