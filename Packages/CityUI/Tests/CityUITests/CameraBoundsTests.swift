import Foundation
import Testing
@testable import CityCore
@testable import CityUI

// rendering-2_5d / Camera stays near the map: away from Apple TV the camera centre may leave the map
// by `GameSession.cameraMapMargin` tiles and no further, so the player can't lose the island.

@MainActor
private func session(cameraAt x: Double, _ y: Double) -> GameSession {
    let session = GameSession(world: World.fixtureWithTerrain(width: 24, height: 24, fill: .grass, seed: 1))
    session.clampsCameraToMap = false
    session.world.camera = Camera(centerX: x, centerY: y, zoom: 1)
    return session
}

/// A drag of 100,000 points each way, and where it leaves the centre of a 24 × 24 map: a horizontal
/// drag moves along both tile axes, a vertical one too, each stopping 8 tiles past the map.
@Test("scenario: Panning far off the map stops at the margin", arguments: [
    (100_000.0, 0.0, -8.0, 32.0), (-100_000.0, 0.0, 32.0, -8.0), (0.0, 100_000.0, -8.0, -8.0), (0.0, -100_000.0, 32.0, 32.0)
])
@MainActor
func scenarioPanningFarOffTheMapStopsAtTheMargin(deltaX: Double, deltaY: Double, centerX: Double, centerY: Double) {
    let session = session(cameraAt: 12, 12)
    session.handlePanDelta(deltaX: deltaX, deltaY: deltaY)
    #expect(session.world.camera == Camera(centerX: centerX, centerY: centerY, zoom: 1))
}

@Test("a pan inside the margin is not clamped")
@MainActor
func panInsideTheMarginIsNotClamped() {
    let session = session(cameraAt: 0.5, 0.5)
    session.handlePanDelta(deltaX: 64, deltaY: 0)
    #expect(session.world.camera == Camera(centerX: -0.5, centerY: 1.5, zoom: 1))
}
