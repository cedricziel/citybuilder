import Foundation
import Testing
@testable import CityCore

// Camera tile-space helpers used by the HUD camera-tracking path
// (add-island-hud-overlay → M8).

@Test("scenario: camera centertile rounds to integer coords")
func scenarioCameraCenterTileRoundsToIntegerCoords() {
    // Exact integer center → identical integer tile.
    var camera = Camera(centerX: 5, centerY: 7, zoom: 1)
    #expect(camera.centerTile() == TileCoordinate(x: 5, y: 7))

    // Fractional center, well inside one tile → that tile.
    camera = Camera(centerX: 5.3, centerY: 7.8, zoom: 1)
    #expect(camera.centerTile() == TileCoordinate(x: 5, y: 7))

    // Negative center clamps to the math-floor tile.
    camera = Camera(centerX: -0.4, centerY: -1.1, zoom: 1)
    #expect(camera.centerTile() == TileCoordinate(x: -1, y: -2))
}
