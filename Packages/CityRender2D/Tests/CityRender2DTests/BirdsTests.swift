import CityCore
import SpriteKit
import Testing
@testable import CityRender2D

// Scenarios from openspec/changes/add-birds.

private func land(tick: UInt64, coast: Bool = false, zoom: Double = 1) -> WorldSnapshot {
    let base = World.fixtureWithTerrain(width: 12, height: 12, fill: .grass, seed: 1).snapshot()
    let grid = (0 ..< 144).map { coast && $0 % 12 >= 7 ? TerrainType.water : TerrainType.grass }
    return WorldSnapshot(
        tickCount: tick, simulatedTime: base.simulatedTime, mapWidth: 12, mapHeight: 12,
        terrainGrid: grid, occupiedTiles: [:], buildings: [:], carriers: [], economy: base.economy,
        totalPopulation: 0, camera: Camera(centerX: 6, centerY: 6, zoom: zoom)
    )
}

private let view = CGSize(width: 1024, height: 768)

@MainActor
@Test("scenario: a flock crosses by day")
func scenarioAFlockCrossesByDay() throws {
    let layer = BirdLayerNode()
    layer.reconcile(snapshot: land(tick: 180), viewSize: view, reduceMotion: false, now: 0)
    #expect(layer.flock == nil)
    let due = try #require(layer.nextFlockAt)
    layer.reconcile(snapshot: land(tick: 181), viewSize: view, reduceMotion: false, now: due + 0.1)
    let flock = try #require(layer.flock)
    let birds = flock.children.filter { $0.zPosition == 0 }
    #expect(BirdPlanner.flockSizes.contains(birds.count))
    #expect(flock.hasActions())
    #expect(try #require(layer.nextFlockAt) - (due + 0.1) >= BirdPlanner.flockGap.lowerBound)
}

@MainActor
@Test("scenario: no birds at night or with reduce motion")
func scenarioNoBirdsAtNightOrWithReduceMotion() throws {
    let layer = BirdLayerNode()
    layer.reconcile(snapshot: land(tick: 180, coast: true), viewSize: view, reduceMotion: false, now: 0)
    let due = try #require(layer.nextFlockAt)
    layer.reconcile(snapshot: land(tick: 181, coast: true), viewSize: view, reduceMotion: false, now: due + 1)
    #expect(!layer.children.isEmpty)
    layer.reconcile(snapshot: land(tick: 780, coast: true), viewSize: view, reduceMotion: false, now: due + 2)
    #expect(layer.children.isEmpty)
    layer.reconcile(snapshot: land(tick: 180, coast: true), viewSize: view, reduceMotion: true, now: due + 3)
    #expect(layer.children.isEmpty && layer.nextFlockAt == nil)
}

@MainActor
@Test("scenario: gulls wheel over the coast")
func scenarioGullsWheelOverTheCoast() throws {
    let layer = BirdLayerNode()
    layer.reconcile(snapshot: land(tick: 180, coast: true), viewSize: view, reduceMotion: false, now: 0)
    let gulls = try #require(layer.gulls)
    #expect(gulls.children.count == BirdPlanner.gullCount)
    let tile = IsoMath.nearestTile(toScreenPoint: gulls.position)
    #expect(land(tick: 0, coast: true).terrain(at: tile) == .water)
    layer.reconcile(snapshot: land(tick: 240), viewSize: view, reduceMotion: false, now: 0.1)
    #expect(layer.gulls == nil, "no coast, no gulls")
    layer.reconcile(snapshot: land(tick: 241, coast: true, zoom: 0.4), viewSize: view, reduceMotion: false, now: 0.2)
    #expect(layer.gulls == nil, "too far out for gulls")
}

@Test("the coast pick is a water tile beside land, nearest the camera")
func coastPick() {
    let snapshot = land(tick: 0, coast: true)
    let tile = BirdPlanner.coastTile(in: snapshot, xRange: 0 ... 11, yRange: 0 ... 11)
    #expect(tile == TileCoordinate(x: 7, y: 6))
    #expect(BirdPlanner.coastTile(in: land(tick: 0), xRange: 0 ... 11, yRange: 0 ... 11) == nil)
}

@Test("a flock flies in a V behind its leader")
func flockShape() {
    let offsets = BirdPlanner.flockOffsets(count: 7)
    #expect(offsets.first == .zero)
    #expect(offsets.dropFirst().allSatisfy { $0.x < 0 })
    #expect(Set(offsets.map { "\($0.x),\($0.y)" }).count == 7)
}
