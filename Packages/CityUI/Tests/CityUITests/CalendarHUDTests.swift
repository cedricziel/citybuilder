import Testing
@testable import CityCore
@testable import CityUI

// Scenarios from openspec/changes/add-calendar-and-events.

@MainActor
@Test("scenario: hud date text")
func scenarioHudDateText() {
    let base = World.newGame().snapshot()
    let snapshot = WorldSnapshot(
        tickCount: base.tickCount, simulatedTime: base.simulatedTime, mapWidth: base.mapWidth,
        mapHeight: base.mapHeight, terrainGrid: base.terrainGrid, occupiedTiles: base.occupiedTiles,
        buildings: base.buildings, carriers: base.carriers, economy: base.economy,
        totalPopulation: base.totalPopulation, camera: base.camera,
        date: GameDate(year: 1203, season: .autumn)
    )
    let hud = HUDViewModel()
    hud.apply(snapshot)
    #expect(hud.dateText == "Autumn 1203")
}

@MainActor
@Test("scenario: banner appears and expires")
func scenarioBannerAppearsAndExpires() throws {
    let seed = try #require((UInt64(0) ..< 500).first {
        World.fixtureWithTerrain(width: 6, height: 6, fill: .grass, seed: $0).historyEvent(forYear: 1201) == .tradeCaravan
    })
    var world = World.fixtureWithTerrain(width: 6, height: 6, fill: .grass, seed: seed)
    world.calendar = CalendarState(startYear: 1200, isActive: true)
    for _ in 0 ..< 2399 {
        world.tick()
    }
    let session = GameSession(world: world)
    #expect(session.banner == nil)
    session.step()
    #expect(session.banner?.title == "Trade caravan")
    for _ in 0 ..< 59 {
        session.step()
    }
    #expect(session.banner?.title == "Trade caravan")
    session.step()
    #expect(session.banner == nil)
}
