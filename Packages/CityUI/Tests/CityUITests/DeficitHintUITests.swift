import Testing
@testable import CityCore
@testable import CityUI

// platform-shells / Deficit hint (openspec/changes/deficit-hint).

/// A grass world with $1 and two sawmills' upkeep, so its first
/// collection, at tick 50, takes the treasury below zero.
@MainActor
private func townAboutToGoRed() -> GameSession {
    var world = World.fixtureWithTerrain(width: 20, height: 20, fill: .grass, seed: 1)
    for anchor in [TileCoordinate(x: 2, y: 2), TileCoordinate(x: 6, y: 2)] {
        let id = EntityID(raw: world.nextEntityRaw)
        world.nextEntityRaw &+= 1
        world.buildings[id] = Building(id: id, kind: .sawmill, anchor: anchor, state: .operational)
        for tile in BuildingCatalog.spec(for: .sawmill).footprint.tiles(anchor: anchor) {
            world.occupiedTiles[tile] = id
        }
        world.stockpiles[id] = World.stockpileCapacity(for: .sawmill).map { Stockpile(capacity: $0) }
    }
    world.economy.balance = 1
    return GameSession(world: world)
}

@MainActor
@Test("scenario: deficit hint names the cause")
func scenarioDeficitHintNamesTheCause() {
    let session = townAboutToGoRed()
    while session.world.tickCount < Economy.taxIntervalTicks {
        session.step()
    }
    let figures = session.world.playerTaxAndUpkeep
    #expect(figures.upkeep > figures.tax)
    #expect(session.world.economy.balance < 0)
    #expect(session.banner?.title == "In the red: upkeep $\(figures.upkeep) vs tax $\(figures.tax)")
    #expect(session.banner?.description
        == "Sell surplus at the town center's market, demolish idle buildings, or build houses before more huts.")
    // Funds keep the game going; the hint stays up for 150 ticks.
    session.world.economy.balance = 10000
    for _ in 0 ..< 149 {
        session.step()
    }
    #expect(session.banner?.title.hasPrefix("In the red") == true)
    session.step()
    #expect(session.banner == nil)
}

@MainActor
@Test("scenario: deficit hint shows once")
func scenarioDeficitHintShowsOnce() {
    let session = GameSession(world: World.newGame())
    session.noteBannerEvents(in: [.bankruptcyWarning(deficitTicks: 1)])
    #expect(session.banner?.title.hasPrefix("In the red") == true)
    session.bannerState = nil
    session.noteBannerEvents(in: [.bankruptcyWarning(deficitTicks: 1)])
    #expect(session.banner == nil)
}
