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
    let town = UITestSeed.world(fromArguments: ["-uiTestSeedTown", "-uiTestShowcase", "craft"])
    #expect(town?.buildings.values.contains { $0.kind == .bakery } == true)
}
