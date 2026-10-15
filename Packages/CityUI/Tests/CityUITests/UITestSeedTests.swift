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

@Test("The town seed has finished houses beside the town center under the default camera")
@MainActor
func townSeedHasFinishedHousesUnderTheDefaultCamera() {
    let world = UITestSeed.townWorld()
    let houses = world.buildings.values.filter { $0.kind == .house && $0.owner == .player }
    #expect(houses.count == 4)
    #expect(houses.allSatisfy { $0.state == .operational })
    #expect(world.camera == World.newGame(layout: .singleIsland, seed: 0).camera)
}

@Test("The town seed can start in a given season, for seasonal art shots")
@MainActor
func townSeedStartsInTheRequestedSeason() {
    for season in [Season.autumn, .winter] {
        let world = UITestSeed.townWorld(season: season)
        #expect(world.date.season == season)
        #expect(TimeOfDay(tick: world.tickCount).phase == .day, "screenshots need daylight")
    }
    #expect(UITestSeed.season(fromArguments: ["app", "-uiTestSeason", "winter"]) == .winter)
    #expect(UITestSeed.season(fromArguments: ["app"]) == nil)
}
