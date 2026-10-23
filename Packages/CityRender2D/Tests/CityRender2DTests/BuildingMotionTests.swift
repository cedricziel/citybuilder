import CityCore
import SpriteKit
import Testing
@testable import CityRender2D

// rendering-2_5d / Building animations follow pause and Reduce Motion.

@MainActor private let rest = SKTexture()
@MainActor private let turned = SKTexture()

/// A building node resting on `rest`, its animation armed in `state`. The test bundle has no atlas,
/// so the loop stands in for a mill's frames.
@MainActor
private func mill(_ state: BuildingMotion.State) -> SKSpriteNode {
    let node = SKSpriteNode(texture: rest)
    let loop = SKAction.repeatForever(.sequence([.setTexture(turned), .wait(forDuration: 0.2), .setTexture(rest), .wait(forDuration: 0.2)]))
    BuildingMotion.arm(loop, on: node, state: state)
    return node
}

@MainActor
private func speed(_ node: SKNode) -> CGFloat? {
    node.action(forKey: BuildingMotion.key)?.speed
}

/// A scene with one mill on screen, its last tick seen at time 0.
@MainActor
private func sceneWithMill() -> (IsoWorldScene, SKSpriteNode) {
    let scene = IsoWorldScene()
    let node = mill(scene.buildingMotionState)
    scene.buildingNodes[TileCoordinate(x: 3, y: 3)] = node
    scene.noteTick(1, now: 0)
    return (scene, node)
}

@MainActor
@Test("scenario: Reduce Motion rests a building on its first frame")
func reduceMotionRestsABuildingOnItsFirstFrame() {
    let (scene, node) = sceneWithMill()
    node.texture = turned
    scene.reduceMotion = true
    scene.updateBuildingMotion(now: 0.1)
    #expect(speed(node) == 0)
    #expect(node.texture === rest)
    scene.reduceMotion = false
    scene.noteTick(2, now: 0.2)
    scene.updateBuildingMotion(now: 0.2)
    #expect(speed(node) == 1)
}

@MainActor
@Test("scenario: Pausing holds a building's animation")
func pausingHoldsABuildingsAnimation() {
    let (scene, node) = sceneWithMill()
    node.texture = turned
    scene.updateBuildingMotion(now: 1)
    #expect(scene.buildingMotionState == .held)
    #expect(speed(node) == 0)
    #expect(node.texture === turned)
    scene.noteTick(2, now: 1.1)
    scene.updateBuildingMotion(now: 1.1)
    #expect(speed(node) == 1)
}

@MainActor
@Test("a building armed while paused or under Reduce Motion starts still")
func buildingArmedWhileStillStartsStill() {
    #expect(speed(mill(.running)) == 1)
    #expect(speed(mill(.held)) == 0)
    let stopped = mill(.stopped)
    #expect(speed(stopped) == 0)
    #expect(stopped.texture === rest)
}

@MainActor
@Test("only the animation stops: a building's own children keep moving")
func onlyTheAnimationStops() {
    let node = mill(.running)
    let badge = SKNode()
    badge.run(.repeatForever(.fadeAlpha(to: 0.5, duration: 0.6)), withKey: "pulse")
    node.addChild(badge)
    BuildingMotion.apply(.stopped, to: node)
    #expect(node.speed == 1)
    #expect(badge.action(forKey: "pulse")?.speed == 1)
}

/// An operational `kind` facing `orientation`, as the scene draws it, with every frame of its loop
/// stubbed in for the atlas the test bundle lacks.
@MainActor
private func shoreNode(_ kind: BuildingKind, facing orientation: ShoreOrientation, in scene: IsoWorldScene) throws -> SKSpriteNode {
    let entry = try #require(SpriteAnimation.entry(for: .buildingOperational(kind)))
    let names = (0 ..< entry.frameCount).map {
        ShoreOrientationMath.textureName(kind: kind, orientation: orientation, state: .operational, frame: $0)
    }
    SpriteAtlas.stub(Dictionary(uniqueKeysWithValues: names.map { ($0, SKTexture()) }))
    defer { SpriteAtlas.stub([:]) }
    let spec = SpriteSpec(coord: TileCoordinate(x: 4, y: 4), kind: .building(
        kind: kind, state: .operational, footprint: BuildingCatalog.spec(for: kind).footprint,
        constructionFrameIndex: nil, orientation: orientation, isWaitingForMaterials: false
    ))
    return try #require(scene.makeBuildingNode(for: spec) as? SKSpriteNode)
}

/// #120 went unnoticed because nothing checked that a shore building's node animates.
@MainActor
@Test("an operational port and shipyard run their animation, still when built under Reduce Motion")
func operationalShoreBuildingsRunTheirAnimation() throws {
    let scene = IsoWorldScene()
    let port = try shoreNode(.port, facing: .s, in: scene)
    let yard = try shoreNode(.shipyard, facing: .w, in: scene)
    #expect(speed(port) == 1)
    #expect(speed(yard) == 1)
    scene.buildingMotionState = .stopped
    #expect(try speed(shoreNode(.port, facing: .e, in: scene)) == 0)
}
