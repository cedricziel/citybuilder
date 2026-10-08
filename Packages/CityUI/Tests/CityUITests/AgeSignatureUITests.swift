import Testing
@testable import CityCore
@testable import CityUI

// Scenarios from openspec/changes/add-age-signatures.

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

@MainActor
@Test("scenario: commission button")
func scenarioCommissionButton() throws {
    var world = grass()
    let gallery = inject(.gallery, at: TileCoordinate(x: 4, y: 4), in: &world)
    world.economy.balance = 500
    let session = GameSession(world: world)
    session.selectedTile = TileCoordinate(x: 4, y: 4)
    let button = try #require(session.inspector.commission)
    #expect(button.title == "Commission art ($200)")
    #expect(button.isEnabled)
    session.commissionArt()
    #expect(session.world.pendingCommands.contains(.commission(gallery)))
    session.step()
    let running = try #require(session.inspector.commission)
    #expect(!running.isEnabled)
    #expect(session.inspector.bullets.contains("Commission ends in 2:00"))
}

@MainActor
@Test("commission button is disabled when the balance is short")
func commissionButtonNeedsMoney() throws {
    var world = grass()
    inject(.gallery, at: TileCoordinate(x: 4, y: 4), in: &world)
    world.economy.balance = 150
    let session = GameSession(world: world)
    session.selectedTile = TileCoordinate(x: 4, y: 4)
    #expect(try !#require(session.inspector.commission).isEnabled)
}

@MainActor
@Test("scenario: smoky house note")
func scenarioSmokyHouseNote() {
    var world = grass()
    let house = inject(.house, at: TileCoordinate(x: 4, y: 4), in: &world)
    var pop = HousePopulation()
    pop.tier = .merchants
    pop.population = 8
    world.populations[house] = pop
    let engine = inject(.steamEngine, at: TileCoordinate(x: 8, y: 4), in: &world)
    world.buildings[engine]?.fuelled = true
    let session = GameSession(world: world)
    session.selectedTile = TileCoordinate(x: 4, y: 4)
    #expect(session.inspector.bullets.contains("Smoky: −2 residents"))
    #expect(session.inspector.bullets.contains("Residents: 8/6"))
}

@MainActor
@Test("signature inspector lines")
func signatureInspectorLines() {
    var world = grass()
    let monument = inject(.monument, at: TileCoordinate(x: 2, y: 2), in: &world)
    world.buildings[monument]?.projectStages = 12
    inject(.guildHall, at: TileCoordinate(x: 2, y: 10), in: &world)
    inject(.sawmill, at: TileCoordinate(x: 6, y: 10), in: &world)
    let engine = inject(.steamEngine, at: TileCoordinate(x: 20, y: 2), in: &world)
    inject(.powerPlant, at: TileCoordinate(x: 20, y: 20), in: &world)
    let session = GameSession(world: world)
    func lines(at tile: TileCoordinate) -> [String] {
        session.selectedTile = tile
        return session.inspector.bullets
    }
    #expect(lines(at: TileCoordinate(x: 2, y: 2)).contains("Stage 12 of 25"))
    #expect(lines(at: TileCoordinate(x: 2, y: 10)).contains("Speeds up 1 workshop"))
    #expect(lines(at: TileCoordinate(x: 20, y: 2)).contains("Out of charcoal"))
    #expect(lines(at: TileCoordinate(x: 20, y: 20)).contains("Out of charcoal"))
    session.world.buildings[engine]?.fuelled = true
    session.world.buildings[monument]?.projectStages = 25
    #expect(lines(at: TileCoordinate(x: 20, y: 2)).contains("Fuelled"))
    #expect(lines(at: TileCoordinate(x: 20, y: 2)).contains("Speeds up 0 workshops · smokes 0 houses"))
    #expect(lines(at: TileCoordinate(x: 2, y: 2)).contains("Complete: taxes +10%"))
}

@MainActor
@Test("scenario: out of charcoal banner")
func scenarioOutOfCharcoalBanner() {
    let session = GameSession(world: grass())
    session.noteBannerEvents(in: [.fuelRanOut(building: EntityID(raw: 3), kind: .steamEngine)])
    #expect(session.banner?.title == "Steam engine is out of charcoal")
    session.noteBannerEvents(in: [.monumentCompleted(building: EntityID(raw: 2))])
    #expect(session.banner?.title == "The monument is complete")
    session.noteBannerEvents(in: [.commissionEnded(building: EntityID(raw: 4))])
    #expect(session.banner?.title == "The gallery's commission has ended")
}
