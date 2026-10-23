import CityCore
import SpriteKit
import Testing
@testable import CityRender2D

// Scenarios from openspec/changes/add-tree-sway.

/// The ground node for a tile with an object on it, and its object.
@MainActor
private func tile(_ kind: TerrainType, at coord: TileCoordinate, in scene: IsoWorldScene) -> (ground: SKNode, clump: SKNode?) {
    let ground = scene.makeTerrainNode(
        kind: kind, coord: coord, object: TerrainObject(kind: kind, density: .medium, variant: 0)
    )
    return (ground, ground.childNode(withName: IsoWorldScene.terrainObjectNodeName))
}

@MainActor
private func clump(_ kind: TerrainType, at coord: TileCoordinate, in scene: IsoWorldScene) -> SKNode? {
    tile(kind, at: coord, in: scene).clump
}

@MainActor
private func swayingScene() -> IsoWorldScene {
    let scene = IsoWorldScene()
    scene.size = CGSize(width: 1024, height: 768)
    scene.hasSprite = { _ in true }
    return scene
}

@MainActor
@Test("scenario: a tree clump sways")
func scenarioATreeClumpSways() throws {
    let scene = swayingScene()
    let tree = try #require(clump(.forest, at: TileCoordinate(x: 4, y: 7), in: scene))
    #expect(tree.action(forKey: TreeSway.key) != nil && tree.speed == 1)
    #expect(TreeSway.amplitude <= 0.7 * .pi / 180 + 1e-9)
    // Neighbours start at different points of the period.
    let phases = Set((0 ..< 6).map { TreeSway.phase(for: TileCoordinate(x: $0, y: 7)) })
    #expect(phases.count > 3 && phases.allSatisfy { (0 ..< TreeSway.period).contains($0) })
}

@MainActor
@Test("scenario: rock stays still")
func scenarioRockStaysStill() throws {
    let scene = swayingScene()
    let rock = try #require(clump(.mountain, at: TileCoordinate(x: 4, y: 7), in: scene))
    #expect(rock.action(forKey: TreeSway.key) == nil)
}

@MainActor
@Test("scenario: sway stops far out and with reduce motion")
func scenarioSwayStopsFarOutAndWithReduceMotion() throws {
    let scene = swayingScene()
    let (ground, made) = tile(.forest, at: TileCoordinate(x: 4, y: 7), in: scene)
    let tree = try #require(made)
    let spec = SpriteSpec(coord: TileCoordinate(x: 4, y: 7), kind: .terrain(.forest))
    scene.presentSprites[spec] = ground
    tree.zRotation = 0.01
    scene.noteTick(1, now: 0)
    scene.updateTreeSway(zoom: 0.4, now: 0)
    #expect(tree.speed == 0 && tree.zRotation == 0)
    #expect(clump(.forest, at: TileCoordinate(x: 5, y: 7), in: scene)?.speed == 0, "made while stopped")
    scene.updateTreeSway(zoom: 1, now: 0.1)
    #expect(tree.speed == 1)
    scene.reduceMotion = true
    scene.updateTreeSway(zoom: 1, now: 0.15)
    #expect(tree.speed == 0 && tree.zRotation == 0)
}

@MainActor
@Test("a paused game holds the lean")
func pausedGameHoldsTheLean() throws {
    let scene = swayingScene()
    let (ground, made) = tile(.forest, at: TileCoordinate(x: 4, y: 7), in: scene)
    let tree = try #require(made)
    scene.presentSprites[SpriteSpec(coord: TileCoordinate(x: 4, y: 7), kind: .terrain(.forest))] = ground
    scene.noteTick(1, now: 0)
    tree.zRotation = 0.005
    scene.updateTreeSway(zoom: 1, now: 1)
    #expect(tree.speed == 0 && abs(tree.zRotation - 0.005) < 0.0001, "held mid-sway, not reset")
}
