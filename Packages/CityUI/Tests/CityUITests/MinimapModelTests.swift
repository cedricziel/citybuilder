import CoreGraphics
import Foundation
import Testing
@testable import CityCore
@testable import CityUI

// Scenarios from openspec/changes/add-minimap/specs/platform-shells/spec.md,
// Requirement: Minimap.

@Test("scenario: Terrain colours")
func scenarioTerrainColours() {
    let terrain: [TerrainType] = [.water, .beach, .grass, .forest, .mountain, .grass]
    let raster = MinimapTerrainRaster(terrain: terrain, mapWidth: 3, mapHeight: 2)
    #expect(raster.width == 10)
    #expect(raster.height == 5)
    for (index, kind) in terrain.enumerated() {
        let (column, row) = raster.pixelCenter(tileX: index % 3, tileY: index / 3)
        #expect(raster.pixel(column: column, row: row) == MinimapPalette.colour(for: kind), "tile \(index)")
    }
    #expect(raster.pixel(column: 0, row: 0) == .clear, "the corner is off the map")
    #expect(raster.makeImage()?.width == 10)
}

@Test("scenario: Iso orientation")
func scenarioIsoOrientation() {
    let projection = MinimapProjection(mapWidth: 40, mapHeight: 20, size: CGSize(width: 240, height: 120))
    let top = projection.point(tileX: 0, tileY: 0)
    let right = projection.point(tileX: 39, tileY: 0)
    let left = projection.point(tileX: 0, tileY: 19)
    let bottom = projection.point(tileX: 39, tileY: 19)
    #expect(top.y < left.y && top.y < right.y && top.y < bottom.y)
    #expect(bottom.y > left.y && bottom.y > right.y)
    #expect(right.x > top.x && right.x > bottom.x && right.x > left.x)
    #expect(left.x < top.x && left.x < bottom.x)
    // Every corner tile sits inside the minimap.
    for corner in [top, right, left, bottom] {
        #expect(CGRect(x: 0, y: 0, width: 240, height: 120).contains(corner))
    }
}

@Test("Minimap points map back to their tile")
func minimapPointRoundTrips() {
    let projection = MinimapProjection(mapWidth: 40, mapHeight: 20, size: CGSize(width: 240, height: 120))
    let tile = projection.tile(at: projection.point(tileX: 30, tileY: 12))
    #expect(abs(tile.x - 30) < 1e-9 && abs(tile.y - 12) < 1e-9)
}

@MainActor
@Test("scenario: Terrain redraws only when it changes")
func scenarioTerrainRedrawsOnlyWhenItChanges() {
    var world = World.fixtureWithTerrain(width: 6, height: 6, fill: .forest, seed: 1)
    let model = MinimapModel()
    model.apply(world.snapshot())
    model.apply(world.snapshot())
    #expect(model.terrainDrawCount == 1)
    world.terrainGrid[2 * 6 + 3] = .grass
    model.apply(world.snapshot())
    #expect(model.terrainDrawCount == 2)
    let raster = model.terrainRaster
    let (column, row) = raster.pixelCenter(tileX: 3, tileY: 2)
    #expect(raster.pixel(column: column, row: row) == MinimapPalette.colour(for: .grass))
    #expect(raster == MinimapTerrainRaster(terrain: world.terrainGrid, mapWidth: 6, mapHeight: 6), "the repaint matches a full draw")
    #expect(model.terrainImage != nil)
}

/// A Hard archipelago, which seats rival 1 (crimson), with a player house.
private func rivalWorld() -> (World, playerHouse: EntityID) {
    var world = World.newGame(layout: .archipelago, seed: 0, culture: .northernEuropean, difficulty: .hard)
    let id = EntityID(raw: world.nextEntityRaw)
    world.nextEntityRaw &+= 1
    world.buildings[id] = Building(id: id, kind: .house, anchor: TileCoordinate(x: 2, y: 2), state: .operational)
    return (world, id)
}

@MainActor
@Test("scenario: Buildings in their owner's colour")
func scenarioBuildingsInTheirOwnersColour() throws {
    let (world, playerHouse) = rivalWorld()
    let rivalHouse = try #require(world.buildings.values.first { $0.owner == .rival(1) })
    #expect(world.rivals[0].colour == .crimson)
    let model = MinimapModel()
    model.apply(world.snapshot())
    let player = try #require(model.buildings.first { $0.id == playerHouse })
    #expect(player.colour == MinimapRGBA(hex: RivalColour.playerHex))
    #expect(player.width == 2 && player.height == 2)
    let rival = try #require(model.buildings.first { $0.id == rivalHouse.id })
    #expect(rival.colour == MinimapRGBA(hex: RivalColour.crimson.hex))
}

@MainActor
@Test("scenario: Ships as dots")
func scenarioShipsAsDots() throws {
    var world = World.fixtureWithTerrain(width: 20, height: 20, fill: .water, seed: 1)
    let id = EntityID(raw: 900)
    world.ships[id] = Ship(
        id: id,
        position: Fixed2D(x: Fixed(raw: Fixed.scale * 25 / 2), y: Fixed(raw: Fixed.scale * 29 / 4)),
        heading: .zero,
        routeID: nil,
        waypointIdx: 0,
        cargo: [:],
        state: .idle,
        shipClass: .default
    )
    let model = MinimapModel()
    model.apply(world.snapshot())
    #expect(model.ships.count == 1)
    let dot = try #require(model.ships.first)
    #expect(dot.x == 12.5 && dot.y == 7.25)
}

@MainActor
@Test("scenario: Markers refresh at most every 3 ticks")
func scenarioMarkersRefreshAtMostEvery3Ticks() {
    var world = World.fixtureWithTerrain(width: 12, height: 12, fill: .grass, seed: 1)
    world.economy.balance = 100_000
    let model = MinimapModel()
    world.tick()
    model.apply(world.snapshot())
    let before = model.buildings.count
    world.enqueue(.place(.road, at: TileCoordinate(x: 5, y: 5)))
    world.tick()
    model.apply(world.snapshot())
    #expect(world.occupiedTiles[TileCoordinate(x: 5, y: 5)] != nil, "the road is placed")
    #expect(model.buildings.count == before, "no rebuild one tick later")
    for _ in 0 ..< 2 {
        world.tick()
        model.apply(world.snapshot())
    }
    #expect(model.buildings.count == before + 1, "rebuilt within 3 ticks")
}

@Test("scenario: Camera frame")
func scenarioCameraFrame() {
    let camera = Camera(centerX: 20, centerY: 20, zoom: 1.0)
    let span = MinimapProjection.cameraSpan(camera: camera, viewSize: CGSize(width: 640, height: 320))
    #expect(span.across == -10.0 ... 10.0)
    #expect(span.down == 30.0 ... 50.0)
    let projection = MinimapProjection(mapWidth: 40, mapHeight: 40, size: CGSize(width: 160, height: 80))
    let rect = projection.cameraRect(camera: camera, viewSize: CGSize(width: 640, height: 320))
    // 2 points per unit of u, 1 per unit of v.
    #expect(rect == CGRect(x: 60, y: 31, width: 40, height: 20))
}
