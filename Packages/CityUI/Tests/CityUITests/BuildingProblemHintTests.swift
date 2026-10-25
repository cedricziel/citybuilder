import Testing
@testable import CityCore
@testable import CityUI

// platform-shells / Building-problem hint.

/// A grass world with an operational player farm and no road, so the farm shows a status icon.
@MainActor
private func sessionWithRoadlessFarm() -> (GameSession, EntityID) {
    var world = World.fixtureWithTerrain(width: 20, height: 12, fill: .grass, seed: 1)
    world.research = ResearchState(researched: [.scholarship, .feudalOrder, .cultivation])
    let id = EntityID(raw: world.nextEntityRaw)
    world.nextEntityRaw &+= 1
    let anchor = TileCoordinate(x: 6, y: 4)
    world.buildings[id] = Building(id: id, kind: .farm, anchor: anchor, state: .operational)
    for tile in BuildingCatalog.spec(for: .farm).footprint.tiles(anchor: anchor) {
        world.occupiedTiles[tile] = id
    }
    world.stockpiles[id] = World.newStockpile(for: .farm)
    let session = GameSession(world: world)
    session.hideFirstSteps()
    return (session, id)
}

@MainActor
@Test("scenario: a standing problem names the building")
func standingProblemIsNamed() {
    let (session, id) = sessionWithRoadlessFarm()
    #expect(session.world.snapshot().roadDisconnectedBuildings.contains(id))
    for _ in 0 ..< Int(GameSession.problemHintDelayTicks) {
        session.step()
    }
    #expect(session.banner == nil)
    session.step()
    #expect(session.banner?.title == "Farm has a problem")
    #expect(session.banner?.description == "No road: connect it to a road. Tap the building for details.")
}

@MainActor
@Test("scenario: a problem that clears is not named")
func clearedProblemIsNotNamed() throws {
    let (session, id) = sessionWithRoadlessFarm()
    for _ in 0 ..< 50 {
        session.step()
    }
    let anchor = try #require(session.world.buildings[id]?.anchor)
    session.world.enqueue(.place(.road, at: TileCoordinate(x: anchor.x - 1, y: anchor.y)))
    for _ in 0 ..< 200 {
        session.step()
    }
    #expect(session.banner?.title != "Farm has a problem")
}

@MainActor
@Test("scenario: each problem is named once")
func eachProblemIsNamedOnce() {
    let (session, _) = sessionWithRoadlessFarm()
    for _ in 0 ... Int(GameSession.problemHintDelayTicks) {
        session.step()
    }
    #expect(session.banner?.title == "Farm has a problem")
    for _ in 0 ..< Int(GameSession.bannerTicks) + 5 {
        session.step()
    }
    #expect(session.banner == nil)
    for _ in 0 ..< 300 {
        session.step()
    }
    #expect(session.banner == nil)
}
