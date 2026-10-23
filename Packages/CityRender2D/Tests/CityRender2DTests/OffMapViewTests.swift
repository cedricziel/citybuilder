import CityCore
import CoreGraphics
import SpriteKit
import Testing
@testable import CityRender2D

// rendering-2_5d / Camera stays near the map: a view wholly off the map culls to nothing instead of
// trapping on an empty range.

private let meadow = World.fixtureWithTerrain(width: 40, height: 40, fill: .grass, seed: 1).snapshot()

private let offMapCameras = [
    Camera(centerX: -500, centerY: 20, zoom: 1),
    Camera(centerX: 540, centerY: 20, zoom: 1),
    Camera(centerX: 20, centerY: -500, zoom: 1),
    Camera(centerX: 20, centerY: 540, zoom: 1),
    Camera(centerX: -500, centerY: -500, zoom: 0.25),
    Camera(centerX: 540, centerY: 540, zoom: 4)
]

@Test("scenario: A view off the map draws nothing", arguments: offMapCameras)
@MainActor
func scenarioAViewOffTheMapDrawsNothing(camera: Camera) {
    let size = CGSize(width: 1024, height: 768)
    let range = Culling.visibleTileRange(camera: camera, viewSize: size, mapWidth: 40, mapHeight: 40, margin: Culling.screenMargin)
    #expect(range.map(\.xRange) == nil)
    var snapshot = meadow
    snapshot.camera = camera
    let scene = IsoWorldScene()
    scene.size = size
    scene.hasSprite = { _ in true }
    let source = FixedSnapshotSource(snapshot)
    scene.dataSource = source
    scene.update(0)
    #expect(scene.presentSprites.isEmpty)
}
