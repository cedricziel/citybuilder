import CityCore
import CoreGraphics
import Testing
@testable import CityRender2D

// rendering-2_5d / Snapshot-driven rendering (#175): the view as row runs matches the per-tile screen
// test it replaces, and the difference between two views is the set difference of their tiles.

private let viewSize = CGSize(width: 480, height: 320)

@Test(arguments: [
    Camera(centerX: 20, centerY: 20, zoom: 1),
    Camera(centerX: 20.37, centerY: 19.81, zoom: 0.25),
    Camera(centerX: 3.5, centerY: 36.2, zoom: 0.6),
    Camera(centerX: -4, centerY: 50, zoom: 2.3)
])
func visibleTilesMatchTheScreenTest(camera: Camera) throws {
    let view = try #require(VisibleTiles(camera: camera, viewSize: viewSize, mapWidth: 40, mapHeight: 40))
    let bounds = Culling.screenBounds(camera: camera, viewSize: viewSize)
    let scanned = view.yRange.flatMap { row in
        view.xRange.map { TileCoordinate(x: $0, y: row) }
    }.filter { bounds.contains(IsoMath.screenPoint(forTile: $0)) }
    #expect(Set(view.tiles) == Set(scanned))
    #expect(view.tiles.count == scanned.count)
}

@Test(arguments: [(0.0, 0.0, 1.0), (1.0, 0.0, 1.0), (-0.4, 2.7, 1.0), (3.0, -3.0, 0.5), (0.0, 0.0, 2.0)])
func visibleTilesDiffMatchesASetDifference(dx: Double, dy: Double, zoomFactor: Double) throws {
    let before = Camera(centerX: 20.2, centerY: 19.6, zoom: 0.8)
    let after = Camera(centerX: before.centerX + dx, centerY: before.centerY + dy, zoom: before.zoom * zoomFactor)
    let old = try #require(VisibleTiles(camera: before, viewSize: viewSize, mapWidth: 40, mapHeight: 40))
    let new = try #require(VisibleTiles(camera: after, viewSize: viewSize, mapWidth: 40, mapHeight: 40))
    #expect(Set(new.tiles(notIn: old)) == Set(new.tiles).subtracting(old.tiles))
    #expect(Set(old.tiles(notIn: new)) == Set(old.tiles).subtracting(new.tiles))
}
