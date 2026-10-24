import SpriteKit
import Testing
@testable import CityCore
@testable import CityRender2D

// Scenarios from openspec/changes/add-areas-of-effect: rendering-2_5d / Areas of effect while
// placing and selecting.

private func tiles(x: ClosedRange<Int>, y: ClosedRange<Int>) -> Set<TileCoordinate> {
    Set(y.flatMap { row in x.map { TileCoordinate(x: $0, y: row) } })
}

/// A 16 by 16 grass world with forest on `forest`.
private func snapshot(forest: [TileCoordinate] = []) -> WorldSnapshot {
    var world = World.fixtureWithTerrain(width: 16, height: 16, fill: .grass, seed: 1)
    for tile in forest {
        world.terrainGrid[tile.y * 16 + tile.x] = .forest
    }
    return world.snapshot()
}

/// A scene showing a tree clump on each of `trees`, as terrain reconcile would.
@MainActor
private func scene(trees: [TileCoordinate]) -> IsoWorldScene {
    let scene = IsoWorldScene()
    scene.size = CGSize(width: 1024, height: 768)
    scene.hasSprite = { _ in true }
    for coord in trees {
        let object = TerrainObject(kind: .forest, density: .medium, variant: 0)
        let spec = SpriteSpec(coord: coord, kind: .terrain(.forest, object: object))
        scene.presentSprites[spec] = scene.makeTerrainNode(kind: .forest, coord: coord, object: object)
        scene.terrainSpecs[coord] = spec
    }
    return scene
}

@Test("the outline of a rectangle is one loop round its edge")
func rectangleOutlineIsOneLoop() {
    let loops = IsoWorldScene.outlineLoops(around: tiles(x: 2 ... 7, y: 2 ... 7))
    #expect(loops.count == 1)
    #expect(loops.first?.count == 24)
    #expect(loops.first?.first == GridCorner(x: 2, y: 2))
}

@Test("a hole in the area is a loop of its own")
func holeIsItsOwnLoop() {
    var ring = tiles(x: 0 ... 2, y: 0 ... 2)
    ring.remove(TileCoordinate(x: 1, y: 1))
    let loops = IsoWorldScene.outlineLoops(around: ring)
    #expect(loops.map(\.count).sorted() == [4, 12])
}

@MainActor
@Test("scenario: placing a hut outlines its catchment and brightens its trees")
func hutAreaBrightensItsTrees() throws {
    let inReach = [TileCoordinate(x: 2, y: 2), TileCoordinate(x: 7, y: 7)]
    let outOfReach = TileCoordinate(x: 10, y: 4)
    let scene = scene(trees: inReach + [outOfReach])
    let area = AreaOfEffect(tiles: tiles(x: 2 ... 7, y: 2 ... 7), targets: inReach, count: 2)
    scene.areaOfEffectProvider = { area }
    scene.reconcileAreaOfEffect(with: snapshot(forest: inReach + [outOfReach]))
    let names = Set(scene.areaLayer.children.compactMap(\.name))
    #expect(names == [IsoWorldScene.areaUnderStrokeNodeName, IsoWorldScene.areaOutlineNodeName])
    for tree in inReach {
        #expect(try #require(scene.objectNode(at: tree)).shader === IsoWorldScene.areaObjectShader)
    }
    #expect(try #require(scene.objectNode(at: outOfReach)).shader == nil)
}

@MainActor
@Test("scenario: a forester's open grass is tinted")
func foresterGrassIsFilled() throws {
    let scene = scene(trees: [])
    let grass = [TileCoordinate(x: 3, y: 3), TileCoordinate(x: 6, y: 2)]
    scene.areaOfEffectProvider = { AreaOfEffect(tiles: tiles(x: 2 ... 7, y: 2 ... 7), targets: grass, count: 2) }
    scene.reconcileAreaOfEffect(with: snapshot())
    let fill = try #require(scene.areaLayer.childNode(withName: IsoWorldScene.areaTargetFillNodeName) as? SKShapeNode)
    #expect(fill.path?.boundingBox == IsoWorldScene.outlinePath(around: Set(grass)).boundingBox)
}

@MainActor
@Test("scenario: the overlay keeps its node count")
func overlayNodeCountIsFixed() {
    let scene = scene(trees: [])
    let sites = Set((0 ..< 12).flatMap { y in (0 ..< 12).compactMap { x in (x + y).isMultiple(of: 3) ? TileCoordinate(x: x, y: y) : nil } })
    scene.areaOfEffectProvider = { AreaOfEffect(tiles: sites, targets: [TileCoordinate(x: 1, y: 1)], count: 4) }
    scene.reconcileAreaOfEffect(with: snapshot())
    #expect(scene.areaLayer.children.count <= 3)
}

@MainActor
@Test("scenario: trees return to normal")
func treesReturnToNormal() throws {
    let tree = TileCoordinate(x: 3, y: 3)
    let scene = scene(trees: [tree])
    var area: AreaOfEffect? = AreaOfEffect(tiles: tiles(x: 2 ... 7, y: 2 ... 7), targets: [tree], count: 1)
    scene.areaOfEffectProvider = { area }
    scene.reconcileAreaOfEffect(with: snapshot(forest: [tree]))
    area = nil
    scene.reconcileAreaOfEffect(with: snapshot(forest: [tree]))
    #expect(scene.areaLayer.children.isEmpty)
    #expect(try #require(scene.objectNode(at: tree)).shader == nil)
}

@MainActor
@Test("a tree drawn again while the area shows is brightened too")
func rebuiltTreeIsBrightened() throws {
    let tree = TileCoordinate(x: 3, y: 3)
    let scene = scene(trees: [tree])
    scene.areaOfEffectProvider = { AreaOfEffect(tiles: tiles(x: 2 ... 7, y: 2 ... 7), targets: [tree], count: 1) }
    scene.reconcileAreaOfEffect(with: snapshot(forest: [tree]))
    // Terrain reconcile replaces the tile's node, as a new season does.
    let object = TerrainObject(kind: .forest, density: .medium, variant: 0)
    let spec = SpriteSpec(coord: tree, kind: .terrain(.forest, object: object))
    scene.presentSprites[spec] = scene.makeTerrainNode(kind: .forest, coord: tree, object: object)
    scene.spriteReconcileCounts.terrainPasses += 1
    scene.reconcileAreaOfEffect(with: snapshot(forest: [tree]))
    #expect(try #require(scene.objectNode(at: tree)).shader === IsoWorldScene.areaObjectShader)
}

@MainActor
@Test("scenario: placing a mine brightens the rock of the sites")
func mineSiteRockIsBrightened() throws {
    let rock = TileCoordinate(x: 3, y: 3)
    let scene = IsoWorldScene()
    scene.size = CGSize(width: 1024, height: 768)
    scene.hasSprite = { _ in true }
    let object = TerrainObject(kind: .mountain, density: .medium, variant: 0)
    let spec = SpriteSpec(coord: rock, kind: .terrain(.mountain, object: object))
    scene.presentSprites[spec] = scene.makeTerrainNode(kind: .mountain, coord: rock, object: object)
    scene.terrainSpecs[rock] = spec
    var world = World.fixtureWithTerrain(width: 16, height: 16, fill: .grass, seed: 1)
    world.terrainGrid[3 * 16 + 3] = .mountain
    scene.areaOfEffectProvider = { AreaOfEffect(tiles: tiles(x: 2 ... 3, y: 2 ... 3), targets: [rock], count: 1) }
    scene.reconcileAreaOfEffect(with: world.snapshot())
    #expect(try #require(scene.objectNode(at: rock)).shader === IsoWorldScene.areaObjectShader)
    #expect(scene.areaLayer.childNode(withName: IsoWorldScene.areaTargetFillNodeName) == nil)
}
