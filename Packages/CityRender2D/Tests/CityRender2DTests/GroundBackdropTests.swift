import CityCore
import SpriteKit
import Testing
@testable import CityRender2D

// Scenarios from openspec/changes/ground-backdrop (rendering-2_5d).

/// A 12 x 12 sea with an island at (2...10, 2...10): a beach two tiles wide round grass at (4...8, 4...8).
private func islandSnapshot(paint: [TileCoordinate: TerrainType] = [:]) -> WorldSnapshot {
    let base = World.fixtureWithTerrain(width: 12, height: 12, fill: .water, seed: 1).snapshot()
    let grid = base.terrainGrid.indices.map { index -> TerrainType in
        let tile = TileCoordinate(x: index % 12, y: index / 12)
        if let painted = paint[tile] { return painted }
        let island = (2 ... 10).contains(tile.x) && (2 ... 10).contains(tile.y)
        let core = (4 ... 8).contains(tile.x) && (4 ... 8).contains(tile.y)
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
private func backdropDraws(_ scene: IsoWorldScene, at coord: TileCoordinate) throws -> Bool {
    try #require(scene.groundBackdropMap).covers(coord)
}

@Test("The ground backdrop covers every tile of the map and no more")
func groundBackdropCoversTheMap() {
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
@Test("scenario: Plain ground is one node")
func plainGroundIsOneNode() throws {
    let scene = scene(Source(islandSnapshot()))
    // Open water, the plain grass in the island's middle and the plain beach round it.
    for plain in [TileCoordinate(x: 0, y: 6), TileCoordinate(x: 6, y: 6), TileCoordinate(x: 3, y: 6)] {
        #expect(scene.terrainSpecs[plain] == nil, "\(plain)")
        #expect(try backdropDraws(scene, at: plain), "\(plain)")
    }
    #expect(scene.children.count { $0.name == IsoWorldScene.groundBackdropNodeName } == 1)
    #expect(scene.groundBackdropNode?.size == IsoWorldScene.mapBounds(width: 12, height: 12).size)
}

@MainActor
@Test("scenario: Transition tiles keep their sprites")
func transitionTilesKeepTheirSprites() throws {
    // Grass straight on the water at (0, 6) turns the corners round it to beach, so the water tile
    // east of it, (1, 6), draws a beach-water transition as a sprite.
    let rock = TileCoordinate(x: 0, y: 6)
    let scene = scene(Source(islandSnapshot(paint: [rock: .grass])))
    let shore = TileCoordinate(x: 1, y: 6)
    guard case let .terrain(kind, transition, _) = try #require(scene.terrainSpecs[shore]).kind else {
        Issue.record("no terrain sprite at \(shore)")
        return
    }
    #expect(kind == .water && transition != nil)
    #expect(try !backdropDraws(scene, at: shore))
}

@MainActor
@Test("scenario: Plain ground follows the terrain")
func plainGroundFollowsTheTerrain() throws {
    let source = Source(islandSnapshot())
    let scene = scene(source)
    let reef = TileCoordinate(x: 0, y: 1)
    #expect(try backdropDraws(scene, at: reef))
    source.snapshot = islandSnapshot(paint: [reef: .grass])
    scene.update(1)
    #expect(scene.groundSpriteName(at: reef)?.hasPrefix("terrain-grass") == true)
    #expect(try !backdropDraws(scene, at: TileCoordinate(x: 1, y: 1)), "the water round the new land is shore now")
    #expect(scene.terrainSpecs[TileCoordinate(x: 1, y: 1)] != nil)
    #expect(try backdropDraws(scene, at: TileCoordinate(x: 11, y: 6)))
}

@MainActor
@Test("The ground backdrop spans only the screen, clamped to the map")
func groundBackdropSpansOnlyTheScreen() throws {
    let base = World.fixtureWithTerrain(width: 200, height: 200, fill: .water, seed: 1).snapshot()
    let camera = Camera(centerX: 100, centerY: 100, zoom: 1)
    let snapshot = WorldSnapshot(
        tickCount: base.tickCount, simulatedTime: base.simulatedTime, mapWidth: 200, mapHeight: 200, terrainGrid: base.terrainGrid,
        occupiedTiles: [:], buildings: [:], carriers: base.carriers, economy: base.economy,
        totalPopulation: base.totalPopulation, camera: camera, date: GameDate(year: 1200, season: .summer)
    )
    let scene = scene(Source(snapshot))
    let node = try #require(scene.groundBackdropNode)
    let screen = Culling.screenBounds(camera: camera, viewSize: scene.size)
    #expect(!node.isHidden)
    #expect(node.frame.width <= screen.width + 0.5 && node.frame.height <= screen.height + 0.5)
    #expect(node.frame.insetBy(dx: -0.5, dy: -0.5).contains(screen))
}

@MainActor
@Test("scenario: Trees and rocks keep their place over the backdrop")
func treesAndRocksKeepTheirPlaceOverTheBackdrop() throws {
    let wood = TileCoordinate(x: 6, y: 6)
    let scene = scene(Source(islandSnapshot(paint: [wood: .forest])))
    #expect(try backdropDraws(scene, at: wood))
    let clump = try #require(scene.presentSprites.first { $0.key.coord == wood }?.value)
    #expect(clump.name == IsoWorldScene.terrainObjectNodeName && clump.parent === scene)
    // SpriteKit keeps z in Float.
    #expect(Float(clump.zPosition) == Float(IsoWorldScene.objectZ(at: wood)))
    #expect(clump.position == IsoMath.screenPoint(forTile: wood))
    #expect(clump.action(forKey: TreeSway.key) != nil, "it still sways")
}

@Test("scenario: Each tile animates on its own phase")
func eachTileAnimatesOnItsOwnPhase() {
    let grid = [TerrainType](repeating: .water, count: 64 * 64)
    let map = GroundBackdropMap(width: 64, height: 64, grid: grid, transitions: TerrainTransitionMap(width: 64, height: 64, grid: grid))
    let texels = map.texels
    let phases = stride(from: 1, to: texels.count, by: 4).map { texels[$0] }
    #expect(Set(phases).count > 200, "phases spread over the tiles")
}

@MainActor
@Test("scenario: The ground backdrop follows the season")
func groundBackdropFollowsTheSeason() throws {
    let source = Source(islandSnapshot())
    let scene = scene(source)
    let summer = try #require(scene.groundBackdropNode?.shader?.uniformNamed("u_looks")?.textureValue)
    let base = islandSnapshot()
    source.snapshot = WorldSnapshot(
        tickCount: base.tickCount, simulatedTime: base.simulatedTime, mapWidth: 12, mapHeight: 12, terrainGrid: base.terrainGrid,
        occupiedTiles: [:], buildings: [:], carriers: base.carriers, economy: base.economy,
        totalPopulation: base.totalPopulation, camera: base.camera, date: GameDate(year: 1200, season: .winter)
    )
    scene.update(1)
    let winter = try #require(scene.groundBackdropNode?.shader?.uniformNamed("u_looks")?.textureValue)
    #expect(winter !== summer)
}

@MainActor
private func uniform(_ scene: IsoWorldScene, _ name: String) throws -> Float {
    try #require(scene.groundBackdropNode?.shader?.uniformNamed(name)).floatValue
}

@MainActor
@Test("scenario: Pausing holds the ground's animation")
func pausingHoldsTheGroundsAnimation() throws {
    let scene = scene(Source(islandSnapshot()))
    scene.noteTick(1, now: 0)
    scene.updateGroundMotion(now: 0)
    scene.updateGroundMotion(now: 0.2)
    let running = try uniform(scene, "u_clock")
    #expect(running > 0.19 && running < 0.21)
    // No tick for more than 0.3 s: the clock holds, so every tile keeps its frame.
    scene.updateGroundMotion(now: 1)
    scene.updateGroundMotion(now: 2)
    #expect(try uniform(scene, "u_clock") == Float(scene.groundClock))
    let held = try uniform(scene, "u_clock")
    scene.updateGroundMotion(now: 3)
    #expect(try uniform(scene, "u_clock") == held)
    // The next tick runs it on from where it stopped.
    scene.noteTick(2, now: 3.1)
    scene.updateGroundMotion(now: 3.2)
    #expect(try uniform(scene, "u_clock") > held && uniform(scene, "u_clock") < held + 0.25)
    #expect(try uniform(scene, "u_rest") == 0)
}

@MainActor
@Test("scenario: Reduce Motion rests the ground on its first frame")
func reduceMotionRestsTheGroundOnItsFirstFrame() throws {
    let scene = scene(Source(islandSnapshot()))
    scene.noteTick(1, now: 0)
    scene.reduceMotion = true
    scene.updateGroundMotion(now: 0.1)
    #expect(try uniform(scene, "u_rest") == 1)
    scene.reduceMotion = false
    scene.updateGroundMotion(now: 0.2)
    #expect(try uniform(scene, "u_rest") == 0)
}
