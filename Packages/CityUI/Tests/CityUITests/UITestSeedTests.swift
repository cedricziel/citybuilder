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
