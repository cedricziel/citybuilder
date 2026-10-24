import CityCore
import SpriteKit
import Testing
@testable import CityRender2D

// Scenarios from openspec/changes/add-fish-and-sawdust.

private let mill = Building(id: EntityID(raw: 1), kind: .sawmill, anchor: TileCoordinate(x: 4, y: 8), state: .operational)

/// Land west of column 12, sea east of it.
private func coast(
    tick: UInt64 = 180, zoom: Double = 1, issues: [EntityID: BuildingIssue] = [:], buildings: [Building] = [mill]
) -> WorldSnapshot {
    let base = World.fixtureWithTerrain(width: 24, height: 24, fill: .grass, seed: 1).snapshot()
    return WorldSnapshot(
        tickCount: tick, simulatedTime: base.simulatedTime, mapWidth: 24, mapHeight: 24,
        terrainGrid: (0 ..< 576).map { $0 % 24 >= 12 ? .water : .grass }, occupiedTiles: [:],
        buildings: Dictionary(uniqueKeysWithValues: buildings.map { ($0.id, $0) }), carriers: [],
        economy: base.economy, totalPopulation: 0, camera: Camera(centerX: 10, centerY: 10, zoom: zoom),
        buildingIssues: issues, date: GameDate(year: 1200, season: .summer)
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
private func scene(showing snapshot: WorldSnapshot) -> (IsoWorldScene, Source) {
    let scene = IsoWorldScene()
    scene.size = CGSize(width: 1024, height: 768)
    let source = Source(snapshot)
    scene.dataSource = source
    return (scene, source)
}

@MainActor
@Test("scenario: sawdust puffs at a working sawmill")
func scenarioSawdustPuffsAtAWorkingSawmill() throws {
    let (scene, source) = scene(showing: coast())
    scene.update(0)
    let emitter = try #require(scene.sawdustLayer.emitters[mill.id])
    #expect(emitter.name == SawdustLayerNode.emitterName && emitter.parent === scene.sawdustLayer && !emitter.isPaused)
    #expect(emitter.position == SawdustLayerNode.saw(of: mill))
    source.snapshot = coast(tick: 181, issues: [mill.id: .outputStuck(.planks)])
    scene.update(0.1)
    #expect(scene.sawdustLayer.emitters.isEmpty && emitter.parent == nil, "an idle mill makes no sawdust")
    source.snapshot = coast(tick: 182)
    scene.update(0.2)
    #expect(scene.sawdustLayer.emitters[mill.id] === emitter, "the emitter comes back from the pool")
}

@MainActor
@Test("scenario: sawdust rests")
func scenarioSawdustRests() throws {
    let (scene, source) = scene(showing: coast())
    scene.update(0)
    scene.update(1)
    // SKEmitterNode does not expose its particles: a held emitter is paused
    // (its puffs freeze in the air) and lets no new puff out.
    let held = { (emitter: SKEmitterNode) in emitter.isPaused && emitter.particleBirthRate == 0 }
    #expect(try held(#require(scene.sawdustLayer.emitters[mill.id])), "paused")
    source.snapshot = coast(tick: 780)
    scene.update(1.1)
    #expect(try held(#require(scene.sawdustLayer.emitters[mill.id])), "night")
    source.snapshot = coast(tick: 181)
    scene.update(1.2)
    let running = try #require(scene.sawdustLayer.emitters[mill.id])
    #expect(!running.isPaused && running.particleBirthRate == SawdustLayerNode.birthRate)
    // An emitter taken from the pool while the game is still starts held.
    source.snapshot = coast(tick: 182, issues: [mill.id: .outputStuck(.planks)])
    scene.update(1.25)
    source.snapshot = coast(tick: 780)
    scene.update(1.3)
    #expect(try held(#require(scene.sawdustLayer.emitters[mill.id])), "a new emitter at night")
    source.snapshot = coast(tick: 181)
    scene.update(1.35)
    source.snapshot = coast(tick: 183, zoom: 0.4)
    scene.update(1.4)
    #expect(scene.sawdustLayer.emitters.isEmpty, "too far out")
    source.snapshot = coast(tick: 184)
    scene.reduceMotion = true
    scene.update(1.5)
    #expect(scene.sawdustLayer.emitters.isEmpty, "reduce motion")
}

/// How many pixels the sawdust lights around `emitter` on the black
/// `stage` it lives in: the one way to see its particles, which
/// SKEmitterNode does not expose.
@MainActor
private func litPixels(around emitter: SKEmitterNode, on stage: SKScene) -> Int {
    let point = emitter.convert(CGPoint.zero, to: stage)
    let crop = CGRect(x: point.x - 64, y: point.y - 32, width: 128, height: 128)
    let view = SKView(frame: CGRect(origin: .zero, size: crop.size))
    guard let image = view.texture(from: stage, crop: crop)?.cgImage(), let data = image.dataProvider?.data as Data?
    else { return 0 }
    return stride(from: 0, to: data.count, by: 4).count { data[$0] > 40 }
}

@MainActor
@Test("a pooled emitter taken while the game is held still shows its puffs")
func pooledHeldEmitterIsPrewarmed() throws {
    // The layer on a black stage of its own, so only the sawdust draws.
    let stage = SKScene(size: CGSize(width: 256, height: 256))
    stage.backgroundColor = .black
    let layer = SawdustLayerNode()
    stage.addChild(layer)
    let view = CGSize(width: 1024, height: 768)
    layer.reconcile(snapshot: coast(), viewSize: view, reduceMotion: false, still: false)
    let running = try #require(layer.emitters[mill.id])
    // Centre the mill's saw on the stage.
    layer.position = CGPoint(x: 128 - running.position.x, y: 128 - running.position.y)
    #expect(litPixels(around: running, on: stage) > 0, "a running mill puffs")
    // Night falls, the mill stops while it is held, and its emitter goes to
    // the pool paused; then the mill works again before dawn.
    layer.reconcile(snapshot: coast(tick: 780), viewSize: view, reduceMotion: false, still: true)
    layer.reconcile(snapshot: coast(tick: 781, issues: [mill.id: .outputStuck(.planks)]), viewSize: view, reduceMotion: false, still: true)
    layer.reconcile(snapshot: coast(tick: 782), viewSize: view, reduceMotion: false, still: true)
    let emitter = try #require(layer.emitters[mill.id])
    #expect(emitter === running && emitter.isPaused && emitter.particleBirthRate == 0)
    #expect(litPixels(around: emitter, on: stage) > 0, "the prewarmed puffs hang in the air")
}

@MainActor
@Test("scenario: a fish jumps near the coast")
func scenarioAFishJumpsNearTheCoast() throws {
    let (scene, source) = scene(showing: coast())
    scene.update(0)
    #expect(scene.fishLayer.jump == nil)
    let due = try #require(scene.fishLayer.nextJumpAt)
    #expect(FishLayerNode.gap.contains(due))
    source.snapshot = coast(tick: 181)
    scene.update(due + 0.1)
    let jump = try #require(scene.fishLayer.jump)
    #expect(1 + jump.children.count <= 3, "at most 3 nodes")
    let tile = IsoMath.nearestTile(toScreenPoint: jump.position)
    #expect((13 ... 15).contains(tile.x), "open water within 4 tiles of the coast, not the shore tile: \(tile)")
    #expect(try #require(scene.fishLayer.nextJumpAt) - (due + 0.1) >= FishLayerNode.gap.lowerBound)
    source.snapshot = coast(tick: 181)
    scene.update(due + 1)
    #expect(jump.speed == 0, "the jump holds while the game is paused")
}

@MainActor
@Test("open water never counts at the map edge")
func noOpenWaterAtTheMapEdge() {
    // 6 × 6: land in columns 0 and 1, water elsewhere, up to the map edge.
    let base = World.fixtureWithTerrain(width: 6, height: 6, fill: .grass, seed: 1).snapshot()
    let snapshot = WorldSnapshot(
        tickCount: 180, simulatedTime: base.simulatedTime, mapWidth: 6, mapHeight: 6,
        terrainGrid: (0 ..< 36).map { $0 % 6 >= 2 ? .water : .grass }, occupiedTiles: [:], buildings: [:], carriers: [],
        economy: base.economy, totalPopulation: 0, camera: Camera(centerX: 3, centerY: 3, zoom: 1)
    )
    let waters = Set(FishLayerNode.waters(in: snapshot, xRange: 0 ... 5, yRange: 0 ... 5))
    #expect(waters == Set((1 ... 4).flatMap { y in (3 ... 4).map { TileCoordinate(x: $0, y: y) } }))
}

@MainActor
@Test("scenario: no fish")
func scenarioNoFish() {
    let (scene, source) = scene(showing: coast(tick: 780))
    scene.update(0)
    source.snapshot = coast(tick: 781)
    scene.update(30)
    #expect(scene.fishLayer.jump == nil, "night")
    source.snapshot = coast(tick: 182, zoom: 0.4)
    scene.update(60)
    #expect(scene.fishLayer.children.isEmpty && scene.fishLayer.nextJumpAt == nil, "too far out")
    source.snapshot = coast(tick: 183)
    scene.reduceMotion = true
    scene.update(90)
    #expect(scene.fishLayer.children.isEmpty && scene.fishLayer.nextJumpAt == nil, "reduce motion")
}
