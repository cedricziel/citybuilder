import CityCore
import Foundation
import SpriteKit
import Testing
@testable import CityRender2D

// Tests for the waiting-for-materials badge added by
// `add-construction-stalls` → M8. Scenarios from
// openspec/changes/add-construction-stalls/specs/rendering-2_5d/spec.md
// under `Requirement: Waiting-for-materials badge`.

private let footprint = Footprint(width: 2, height: 2)

private func sawmillSpec(state: BuildingState, isWaiting: Bool) -> SpriteSpec {
    SpriteSpec(
        coord: TileCoordinate(x: 0, y: 0),
        kind: .building(
            kind: .sawmill,
            state: state,
            footprint: footprint,
            constructionFrameIndex: state == .constructing ? 0 : nil,
            orientation: nil,
            isWaitingForMaterials: isWaiting
        )
    )
}

@Test("scenario: waiting building shows the waiting badge")
@MainActor
func scenarioWaitingBuildingShowsTheWaitingBadge() {
    let scene = IsoWorldScene()
    let node = scene.makeBuildingNode(for: sawmillSpec(state: .constructing, isWaiting: true))
    let badge = node.childNode(withName: IsoWorldScene.waitingBadgeNodeName)
    #expect(badge != nil, "expected waiting overlay child")
}

@Test("scenario: actively constructing building shows no badge")
@MainActor
func scenarioActivelyConstructingBuildingShowsNoBadge() {
    let scene = IsoWorldScene()
    let node = scene.makeBuildingNode(for: sawmillSpec(state: .constructing, isWaiting: false))
    #expect(node.childNode(withName: IsoWorldScene.waitingBadgeNodeName) == nil)
}

@Test("scenario: operational building shows no badge")
@MainActor
func scenarioOperationalBuildingShowsNoBadge() {
    let scene = IsoWorldScene()
    let node = scene.makeBuildingNode(for: sawmillSpec(state: .operational, isWaiting: false))
    #expect(node.childNode(withName: IsoWorldScene.waitingBadgeNodeName) == nil)
}

@Test("scenario: disconnected building sprite carries the no-road marker")
@MainActor
func scenarioDisconnectedBuildingSpriteCarriesTheNoRoadMarker() {
    let scene = IsoWorldScene()
    let spec = SpriteSpec(
        coord: TileCoordinate(x: 0, y: 0),
        kind: .building(
            kind: .house, state: .operational, footprint: footprint,
            constructionFrameIndex: nil, orientation: nil,
            isWaitingForMaterials: false, isRoadDisconnected: true
        )
    )
    #expect(scene.makeBuildingNode(for: spec).childNode(withName: IsoWorldScene.noRoadBadgeNodeName) != nil)
    #expect(scene.makeBuildingNode(for: sawmillSpec(state: .operational, isWaiting: false))
        .childNode(withName: IsoWorldScene.noRoadBadgeNodeName) == nil)
}

@Test("scenario: a 2×3 building's sprite sits on its footprint")
@MainActor
func scenarioA2x3BuildingsSpriteSitsOnItsFootprint() {
    let spec = SpriteSpec(
        coord: TileCoordinate(x: 0, y: 0),
        kind: .building(
            kind: .port, state: .operational, footprint: Footprint(width: 2, height: 3),
            constructionFrameIndex: nil, orientation: .e, isWaitingForMaterials: false
        )
    )
    let node = IsoWorldScene().makeBuildingNode(for: spec)
    #expect(node.position == CGPoint(x: -16, y: -64))
}

@Test("scenario: square footprints keep their existing anchor")
@MainActor
func scenarioSquareFootprintsKeepTheirExistingAnchor() {
    let node = IsoWorldScene().makeBuildingNode(for: sawmillSpec(state: .operational, isWaiting: false))
    #expect(node.position == CGPoint(x: 0, y: -48))
}

private func houseSpec(tier: HouseTier) -> SpriteSpec {
    SpriteSpec(
        coord: TileCoordinate(x: 0, y: 0),
        kind: .building(
            kind: .house, state: .operational, footprint: footprint,
            constructionFrameIndex: nil, orientation: nil,
            isWaitingForMaterials: false, houseTier: tier
        )
    )
}

@Test("scenario: merchant house uses the tier 3 sprite")
@MainActor
func scenarioMerchantHouseUsesTheTier3Sprite() {
    let node = IsoWorldScene().makeBuildingNode(for: houseSpec(tier: .merchants))
    #expect(node.userData?[IsoWorldScene.textureNameKey] as? String == "building-house-tier3")
}

@Test("scenario: tier change swaps the house sprite")
func scenarioTierChangeSwapsTheHouseSprite() throws {
    var world = World.fixtureWithTerrain(width: 6, height: 6, fill: .grass, seed: 1)
    world.enqueue(.place(.house, at: TileCoordinate(x: 1, y: 1)))
    for _ in 0 ..< 30 {
        world.tick()
    }
    let house = try #require(world.occupiedTiles[TileCoordinate(x: 1, y: 1)])
    let snapshot = world.snapshot()
    var citizens = HousePopulation()
    citizens.tier = .citizens
    let before = SnapshotReconciler.desiredSprites(in: snapshot, xRange: 0 ... 5, yRange: 0 ... 5)
    let after = SnapshotReconciler.desiredSprites(
        in: withHousePopulations(snapshot, [house: citizens]), xRange: 0 ... 5, yRange: 0 ... 5
    )
    let diff = SnapshotReconciler.diff(previous: before, current: after)
    #expect(diff.added.contains { $0.coord == TileCoordinate(x: 1, y: 1) })
    #expect(diff.removed.contains { $0.coord == TileCoordinate(x: 1, y: 1) })
}

private func withHousePopulations(_ base: WorldSnapshot, _ pops: [EntityID: HousePopulation]) -> WorldSnapshot {
    WorldSnapshot(
        tickCount: base.tickCount, simulatedTime: base.simulatedTime, mapWidth: base.mapWidth, mapHeight: base.mapHeight,
        terrainGrid: base.terrainGrid, occupiedTiles: base.occupiedTiles, buildings: base.buildings, carriers: base.carriers,
        ships: base.ships, routes: base.routes, economy: base.economy, totalPopulation: base.totalPopulation, camera: base.camera,
        islandSummaries: base.islandSummaries, roadDisconnectedBuildings: base.roadDisconnectedBuildings,
        housePopulations: pops
    )
}

@Test("placed building keeps its footprint offset from the anchor tile")
@MainActor
func placedBuildingKeepsFootprintOffset() {
    let scene = IsoWorldScene()
    let spec = SpriteSpec(coord: TileCoordinate(x: 10, y: 4), kind: sawmillSpec(state: .operational, isWaiting: false).kind)
    let node = scene.placedNode(for: spec)
    let tile = IsoMath.screenPoint(forTile: spec.coord)
    #expect(node.position == CGPoint(x: tile.x, y: tile.y - 48))
}

@Test("a building nearer the camera draws above one behind it")
@MainActor
func nearerBuildingDrawsAbove() {
    let scene = IsoWorldScene()
    let townCenter = SpriteSpec(
        coord: TileCoordinate(x: 45, y: 46),
        kind: .building(
            kind: .townCenter,
            state: .operational,
            footprint: Footprint(width: 3, height: 3),
            constructionFrameIndex: nil,
            orientation: nil,
            isWaitingForMaterials: false
        )
    )
    let houseInFront = SpriteSpec(
        coord: TileCoordinate(x: 44, y: 49),
        kind: .building(
            kind: .house,
            state: .operational,
            footprint: footprint,
            constructionFrameIndex: nil,
            orientation: nil,
            isWaitingForMaterials: false
        )
    )
    #expect(scene.placedNode(for: houseInFront).zPosition > scene.placedNode(for: townCenter).zPosition)
}
