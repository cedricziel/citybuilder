import CityCore
import SpriteKit
import Testing
@testable import CityRender2D

// add-event-counterplay task 8.2 (rendering-2_5d / Seasonal events are drawn on the map): the watchman
// is a walker with a bucket, never a carrier; ruins, flames and status icons follow the burnt building.

private func snapshot(tick: UInt64, watchmen: [WatchmanWalker]) -> WorldSnapshot {
    let base = World.fixtureWithTerrain(width: 10, height: 10, fill: .grass, seed: 1).snapshot()
    return WorldSnapshot(
        tickCount: tick, simulatedTime: base.simulatedTime, mapWidth: 10, mapHeight: 10,
        terrainGrid: base.terrainGrid, occupiedTiles: [:], buildings: [:], carriers: [],
        economy: base.economy, totalPopulation: 0, camera: base.camera, watchmen: watchmen
    )
}

private let path = [TileCoordinate(x: 1, y: 1), TileCoordinate(x: 2, y: 1), TileCoordinate(x: 3, y: 1)]

private func watchman(at index: Int, dousing: Bool = false) -> WatchmanWalker {
    WatchmanWalker(watch: EntityID(raw: 5), fire: EntityID(raw: 6), path: path, pathIndex: index, isDousing: dousing)
}

@MainActor
@Test("scenario: the watchman walks with his bucket, then stands while he douses")
func watchmanWalksThenStands() throws {
    let scene = IsoWorldScene()
    scene.reconcileCarriers(with: snapshot(tick: 1, watchmen: [watchman(at: 0)]), now: 0)
    let walking = try #require(scene.carrierVisuals[EntityID(raw: 5)])
    #expect(walking.look.figure == .watchman)
    #expect(walking.look.facing == .se)
    #expect(walking.walking)
    scene.reconcileCarriers(with: snapshot(tick: 2, watchmen: [watchman(at: 2, dousing: true)]), now: 0.1)
    let dousing = try #require(scene.carrierVisuals[EntityID(raw: 5)])
    #expect(!dousing.walking)
    // He keeps facing the way he came, toward the fire.
    #expect(dousing.look.facing == .se)
    scene.reconcileCarriers(with: snapshot(tick: 3, watchmen: []), now: 0.2)
    #expect(scene.carrierVisuals.isEmpty)
}

@Test("the watchman's frames are his own walk cycle")
func watchmanFrames() {
    #expect(SpriteAnimation.assetName(for: .watchman(.ne), frame: 0) == "walker-watchman-ne-0")
    #expect(SpriteAtlasRouting.atlasName(for: "walker-watchman-ne-0") == SpriteAtlasRouting.kitAtlasName)
}

private func houseSpec(_ state: BuildingState) -> SpriteSpec {
    SpriteSpec(coord: TileCoordinate(x: 4, y: 4), kind: .building(
        kind: .house, state: state, footprint: Footprint(width: 2, height: 2),
        constructionFrameIndex: nil, orientation: nil, isWaitingForMaterials: false
    ))
}

@MainActor
@Test("scenario: A burning house shows flames, and loses them when the fire is out")
func burningHouseShowsFlames() throws {
    let scene = IsoWorldScene()
    let burning = try #require(scene.makeBuildingNode(for: houseSpec(.burning)) as? SKSpriteNode)
    let fire = try #require(burning.childNode(withName: FireEffect.nodeName))
    #expect(fire.zPosition > 95, "self-lit, over the night shade")
    #expect(abs(burning.colorBlendFactor - FireEffect.soot) < 0.001)
    // The state is part of the sprite's key: the doused house gets a fresh node, without the fire.
    let doused = try #require(scene.makeBuildingNode(for: houseSpec(.operational)) as? SKSpriteNode)
    #expect(doused.childNode(withName: FireEffect.nodeName) == nil)
    #expect(doused.colorBlendFactor == 0)
    #expect(houseSpec(.burning) != houseSpec(.operational))
}

@MainActor
@Test("scenario: under Reduce Motion the flames hold still")
func flamesHoldStillUnderReduceMotion() throws {
    let scene = IsoWorldScene()
    scene.reduceMotion = true
    let burning = try #require(scene.makeBuildingNode(for: houseSpec(.burning)) as? SKSpriteNode)
    let fire = try #require(burning.childNode(withName: FireEffect.nodeName))
    #expect(fire.children.allSatisfy { !$0.hasActions() })
}

@MainActor
@Test("flames grow with the footprint")
func flamesGrowWithTheFootprint() {
    let sizes = [1, 2, 3].map { FireEffect.scale(for: Footprint(width: $0, height: $0)) }
    #expect(sizes == sizes.sorted() && Set(sizes).count == 3)
}

@Test("scenario: a burning building sends up a smoke column, before any chimney")
func burningBuildingSmokes() {
    let base = World.fixtureWithTerrain(width: 10, height: 10, fill: .grass, seed: 1).snapshot()
    let house = Building(id: EntityID(raw: 1), kind: .sawmill, anchor: TileCoordinate(x: 2, y: 2), state: .burning)
    let snapshot = WorldSnapshot(
        tickCount: 1, simulatedTime: base.simulatedTime, mapWidth: 10, mapHeight: 10,
        terrainGrid: base.terrainGrid, occupiedTiles: [:], buildings: [house.id: house], carriers: [],
        economy: base.economy, totalPopulation: 0, camera: base.camera
    )
    let sources = ChimneyPlanner.sources(in: snapshot)
    #expect(sources.map(\.style) == [.fireSmoke])
    let smithy = SmokeSource(id: EntityID(raw: 2), anchor: TileCoordinate(x: 2, y: 2), kind: .toolsmith, style: .smoke)
    let chosen = ChimneyPlanner.select(
        [smithy] + sources, xRange: 0 ... 9, yRange: 0 ... 9, camera: Camera(centerX: 2, centerY: 2, zoom: 0.1)
    )
    #expect(chosen.first?.style == .fireSmoke)
}
