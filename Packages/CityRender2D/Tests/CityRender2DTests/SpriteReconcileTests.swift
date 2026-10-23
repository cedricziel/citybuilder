import CityCore
import CoreGraphics
import SpriteKit
import Testing
@testable import CityRender2D

// rendering-2_5d / Snapshot-driven rendering (#175): the scene reconciles its sprites only on frames
// that change the view, the terrain or the buildings, and a pan touches only the tiles at the edges.

/// A 40 × 40 meadow with a forest at 10–17 × 10–17, rock at 24–29 × 8–13 and a lake at 8–13 × 26–31,
/// a house at (20, 20), and the camera on (20, 20) at `zoom`.
private func meadow(
    camera: Camera = Camera(centerX: 20, centerY: 20, zoom: 1),
    houses: [TileCoordinate] = [TileCoordinate(x: 20, y: 20)],
    paint: [TileCoordinate: TerrainType] = [:]
) -> WorldSnapshot {
    let base = World.fixtureWithTerrain(width: 40, height: 40, fill: .grass, seed: 1).snapshot()
    let grid = base.terrainGrid.indices.map { index -> TerrainType in
        let tile = TileCoordinate(x: index % 40, y: index / 40)
        if let painted = paint[tile] { return painted }
        if (10 ... 17).contains(tile.x), (10 ... 17).contains(tile.y) { return .forest }
        if (24 ... 29).contains(tile.x), (8 ... 13).contains(tile.y) { return .mountain }
        if (8 ... 13).contains(tile.x), (26 ... 31).contains(tile.y) { return .water }
        return .grass
    }
    let buildings = houses.enumerated().map { index, anchor in
        Building(id: EntityID(raw: UInt32(index + 1)), kind: .house, anchor: anchor, state: .operational)
    }
    var occupied: [TileCoordinate: EntityID] = [:]
    for building in buildings {
        for tile in BuildingCatalog.spec(for: building.kind).footprint.tiles(anchor: building.anchor) {
            occupied[tile] = building.id
        }
    }
    return WorldSnapshot(
        tickCount: base.tickCount, simulatedTime: base.simulatedTime, mapWidth: 40, mapHeight: 40, terrainGrid: grid,
        occupiedTiles: occupied, buildings: Dictionary(uniqueKeysWithValues: buildings.map { ($0.id, $0) }),
        carriers: [], economy: base.economy, totalPopulation: base.totalPopulation, camera: camera
    )
}

private let viewSize = CGSize(width: 480, height: 320)

@MainActor
private func scene(showing snapshot: WorldSnapshot) -> (IsoWorldScene, FixedSnapshotSource) {
    let source = FixedSnapshotSource(snapshot)
    let scene = IsoWorldScene()
    scene.size = viewSize
    scene.hasSprite = { _ in true }
    scene.dataSource = source
    scene.update(0)
    return (scene, source)
}

/// The sprites a full rebuild of the frame would place.
@MainActor
private func rebuilt(_ snapshot: WorldSnapshot) -> Set<SpriteSpec> {
    Set(scene(showing: snapshot).0.presentSprites.keys)
}

@MainActor
@Test("scenario: An unchanged frame reconciles nothing")
func anUnchangedFrameReconcilesNothing() {
    let (scene, _) = scene(showing: meadow())
    let first = scene.spriteReconcileCounts
    #expect(first.terrainPasses == 1)
    #expect(first.buildingPasses == 1)
    for frame in 1 ... 5 {
        scene.update(TimeInterval(frame) / 60)
    }
    #expect(scene.spriteReconcileCounts == first)
}

@MainActor
@Test("scenario: A pan redraws only the edges")
func aPanRedrawsOnlyTheEdges() {
    let (scene, source) = scene(showing: meadow(camera: Camera(centerX: 20, centerY: 20, zoom: 0.5)))
    let shown = scene.terrainSpecs.count
    let before = scene.spriteReconcileCounts
    source.snapshot.camera = Camera(centerX: 21, centerY: 20, zoom: 0.5)
    scene.update(1)
    let after = scene.spriteReconcileCounts
    let touched = after.tilesAdded - before.tilesAdded + after.tilesRemoved - before.tilesRemoved
    #expect(after.terrainPasses == before.terrainPasses + 1)
    #expect(touched > 0)
    #expect(touched * 5 < shown)
    #expect(Set(scene.presentSprites.keys) == rebuilt(source.snapshot))
}

@MainActor
@Test("scenario: A new building redraws only the tiles round it")
func aNewBuildingRedrawsOnlyTheTilesRoundIt() {
    let (scene, source) = scene(showing: meadow())
    let before = scene.spriteReconcileCounts
    source.snapshot = meadow(houses: [TileCoordinate(x: 20, y: 20), TileCoordinate(x: 18, y: 12)])
    scene.update(1)
    let after = scene.spriteReconcileCounts
    #expect(after.buildingPasses == before.buildingPasses + 1)
    #expect(after.tilesAdded - before.tilesAdded < 20)
    #expect(Set(scene.presentSprites.keys) == rebuilt(source.snapshot))
}

@MainActor
@Test("scenario: Incremental frames match a full rebuild")
func incrementalFramesMatchAFullRebuild() {
    let (scene, source) = scene(showing: meadow())
    let frames = [
        meadow(camera: Camera(centerX: 22.3, centerY: 18.7, zoom: 1)),
        meadow(camera: Camera(centerX: 22.3, centerY: 18.7, zoom: 0.25)),
        meadow(camera: Camera(centerX: 5, centerY: 35, zoom: 0.5)),
        meadow(camera: Camera(centerX: 15, centerY: 15, zoom: 2), paint: [TileCoordinate(x: 13, y: 13): .grass]),
        meadow(camera: Camera(centerX: 15, centerY: 15, zoom: 2), houses: [TileCoordinate(x: 16, y: 18)]),
        meadow(camera: Camera(centerX: 38, centerY: 2, zoom: 0.75))
    ]
    for (frame, snapshot) in frames.enumerated() {
        source.snapshot = snapshot
        scene.update(TimeInterval(frame + 1))
        #expect(Set(scene.presentSprites.keys) == rebuilt(snapshot), "frame \(frame)")
        #expect(scene.presentSprites.values.allSatisfy { $0.parent === scene })
    }
}
