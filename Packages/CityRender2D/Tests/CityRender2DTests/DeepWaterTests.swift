import CityCore
import SpriteKit
import Testing
@testable import CityRender2D

// Scenarios from openspec/changes/deep-water-backdrop (rendering-2_5d).

/// A 12 x 12 sea with a 4 x 4 island at (4...7, 4...7): beach round grass.
private func islandSnapshot(paint: [TileCoordinate: TerrainType] = [:]) -> WorldSnapshot {
    let base = World.fixtureWithTerrain(width: 12, height: 12, fill: .water, seed: 1).snapshot()
    let grid = base.terrainGrid.indices.map { index -> TerrainType in
        let tile = TileCoordinate(x: index % 12, y: index / 12)
        if let painted = paint[tile] { return painted }
        let island = (4 ... 7).contains(tile.x) && (4 ... 7).contains(tile.y)
        let core = (5 ... 6).contains(tile.x) && (5 ... 6).contains(tile.y)
        return core ? .grass : island ? .beach : .water
    }
    var camera = base.camera
    camera = Camera(centerX: 6, centerY: 6, zoom: 1)
    return WorldSnapshot(
        tickCount: base.tickCount, simulatedTime: base.simulatedTime, mapWidth: 12, mapHeight: 12, terrainGrid: grid,
        occupiedTiles: [:], buildings: [:], carriers: base.carriers, economy: base.economy,
        totalPopulation: base.totalPopulation, camera: camera, date: GameDate(year: 1200, season: .summer)
    )
}

@MainActor
private final class Source: IsoWorldDataSource {
    var snapshot: WorldSnapshot
    init(_ snapshot: WorldSnapshot) {
        self.snapshot = snapshot
    }

    func currentSnapshot() -> WorldSnapshot? {
        snapshot
    }
}

@MainActor
private func scene(_ source: Source) -> IsoWorldScene {
    let scene = IsoWorldScene()
    scene.size = CGSize(width: 1024, height: 768)
    scene.hasSprite = { _ in true }
    scene.dataSource = source
    scene.update(0)
    return scene
}

@MainActor
private func hasWaterTile(_ scene: IsoWorldScene, at coord: TileCoordinate) throws -> Bool {
    try #require(scene.deepWaterMask).contains(coord)
}

@Test("The open-water backdrop covers every tile of the map and no more")
func openWaterBackdropCoversTheMap() {
    let bounds = IsoWorldScene.mapBounds(width: 300, height: 200)
    let half = CGSize(width: IsoMath.tileWidth / 2, height: IsoMath.tileHeight / 2)
    // The map's four outer corners: west of (0, 199), north of (0, 0), east of (299, 0), south of (299, 199).
    let west = IsoMath.screenPoint(forTile: TileCoordinate(x: 0, y: 199))
    let north = IsoMath.screenPoint(forTile: TileCoordinate(x: 0, y: 0))
    let east = IsoMath.screenPoint(forTile: TileCoordinate(x: 299, y: 0))
    let south = IsoMath.screenPoint(forTile: TileCoordinate(x: 299, y: 199))
    #expect(bounds.minX == west.x - half.width && bounds.maxX == east.x + half.width)
    #expect(bounds.maxY == north.y + half.height && bounds.minY == south.y - half.height)
}

@MainActor
@Test("scenario: Open water is one node")
func openWaterIsOneNode() throws {
    let scene = scene(Source(islandSnapshot()))
    let open = TileCoordinate(x: 1, y: 6)
    #expect(scene.terrainSpecs[open] == nil)
    #expect(try hasWaterTile(scene, at: open))
    #expect(scene.children.count { $0.name == IsoWorldScene.deepWaterNodeName } == 1)
    #expect(scene.deepWaterNode?.size == IsoWorldScene.mapBounds(width: 12, height: 12).size)
}

@MainActor
@Test("scenario: Shore water keeps its transition sprite")
func shoreWaterKeepsItsTransitionSprite() throws {
    // Grass straight on the water at (9, 9) turns the corners round it to beach, so the water tile
    // west of it, (8, 9), draws a beach-water transition as a sprite.
    let scene = scene(Source(islandSnapshot(paint: [TileCoordinate(x: 9, y: 9): .grass])))
    let shore = TileCoordinate(x: 8, y: 9)
    guard case let .terrain(kind, transition, _) = try #require(scene.terrainSpecs[shore]).kind else {
        Issue.record("no terrain sprite at \(shore)")
        return
    }
    #expect(kind == .water && transition != nil)
    #expect(try !hasWaterTile(scene, at: shore))
    // The island's beach draws its own edge: beach and grass tiles are never open water.
    #expect(scene.terrainSpecs[TileCoordinate(x: 4, y: 6)] != nil)
    #expect(try !hasWaterTile(scene, at: TileCoordinate(x: 4, y: 6)))
    #expect(try !hasWaterTile(scene, at: TileCoordinate(x: 5, y: 5)))
}

@MainActor
@Test("scenario: Open water follows the terrain")
func openWaterFollowsTheTerrain() throws {
    let source = Source(islandSnapshot())
    let scene = scene(source)
    let reef = TileCoordinate(x: 1, y: 1)
    #expect(try hasWaterTile(scene, at: reef))
    source.snapshot = islandSnapshot(paint: [reef: .grass])
    scene.update(1)
    #expect(try !hasWaterTile(scene, at: reef))
    #expect(try !hasWaterTile(scene, at: TileCoordinate(x: 0, y: 1)), "the water round the new land is shore now")
    #expect(scene.terrainSpecs[TileCoordinate(x: 0, y: 1)] != nil)
    #expect(try hasWaterTile(scene, at: TileCoordinate(x: 10, y: 10)))
}
