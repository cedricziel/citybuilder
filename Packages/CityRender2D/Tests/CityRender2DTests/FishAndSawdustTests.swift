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
    #expect(emitter.name == SawdustLayerNode.emitterName && emitter.parent === scene.sawdustLayer && emitter.speed == 1)
    #expect(emitter.position == SawdustLayerNode.saw(of: mill))
    source.snapshot = coast(tick: 181, issues: [mill.id: .storageFull])
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
    #expect(try #require(scene.sawdustLayer.emitters[mill.id]).speed == 0, "paused")
    source.snapshot = coast(tick: 780)
    scene.update(1.1)
    #expect(try #require(scene.sawdustLayer.emitters[mill.id]).speed == 0, "night")
    source.snapshot = coast(tick: 181)
    scene.update(1.2)
    #expect(try #require(scene.sawdustLayer.emitters[mill.id]).speed == 1)
    source.snapshot = coast(tick: 182, zoom: 0.4)
    scene.update(1.3)
    #expect(scene.sawdustLayer.emitters.isEmpty, "too far out")
    source.snapshot = coast(tick: 183)
    scene.reduceMotion = true
    scene.update(1.4)
    #expect(scene.sawdustLayer.emitters.isEmpty, "reduce motion")
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
