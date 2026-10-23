import CityCore
import SpriteKit
import Testing
@testable import CityRender2D

// A figure behind a building is hidden by it; one in front draws over it (rendering-2_5d).

/// The z a 2×2 house anchored at (4, 4) gets: its footprint centre's depth, 4 + 4 + 2.
@MainActor private var houseZ: CGFloat {
    IsoWorldScene.depthZ(10)
}

private func feet(onTile x: Double, _ y: Double) -> CGPoint {
    IsoMath.screenPoint(forTileFractionalX: x + 0.5, fractionalY: y + 0.5)
}

@MainActor
@Test("a figure behind a house sorts below it, one in front above it")
func figuresSortAgainstAHouse() {
    // Behind: the road along the house's back edge, and halfway out to the corner beside it.
    #expect(IsoWorldScene.figureZ(at: feet(onTile: 5, 3)) < houseZ)
    #expect(IsoWorldScene.figureZ(at: feet(onTile: 5.5, 3)) < houseZ)
    // In front: the road along the house's front edges.
    #expect(IsoWorldScene.figureZ(at: feet(onTile: 4, 6)) > houseZ)
    #expect(IsoWorldScene.figureZ(at: feet(onTile: 6, 4)) > houseZ)
    // Level with its centre, beside it: just above it, and below the next depth.
    let corner = IsoWorldScene.figureZ(at: feet(onTile: 6, 3))
    #expect(corner > houseZ && corner < IsoWorldScene.depthZ(10.5))
}

@MainActor
@Test("a gliding carrier sorts by where it is, not by the tile it heads for")
func carriersSortByWhereTheyAre() throws {
    let base = World.fixtureWithTerrain(width: 12, height: 12, fill: .grass, seed: 1).snapshot()
    let carrier = Carrier(
        id: EntityID(raw: 9),
        path: [TileCoordinate(x: 5, y: 3), TileCoordinate(x: 6, y: 3), TileCoordinate(x: 6, y: 4)],
        mission: .deliver(good: .wood, amount: 1, fromProducer: EntityID(raw: 1), toWarehouse: EntityID(raw: 2))
    )
    let snapshot = WorldSnapshot(
        tickCount: 1, simulatedTime: base.simulatedTime, mapWidth: 12, mapHeight: 12,
        terrainGrid: base.terrainGrid, occupiedTiles: [:], buildings: [:], carriers: [carrier],
        economy: base.economy, totalPopulation: 0, camera: base.camera
    )
    let scene = IsoWorldScene()
    scene.reconcileCarriers(with: snapshot, now: 0)
    let node = try #require(scene.carrierVisuals[carrier.id]?.node)
    // On (5, 3), behind the house, heading for the corner beside it: hidden.
    #expect(node.zPosition < houseZ)
    // Midway through a glide the next frame re-sorts it where it stands.
    node.position = feet(onTile: 5.5, 3)
    scene.reconcileCarriers(with: snapshot, now: 0.05)
    #expect(abs(node.zPosition - IsoWorldScene.figureZ(at: node.position)) < 0.0001 && node.zPosition < houseZ)
    node.position = feet(onTile: 6, 3.5)
    scene.reconcileCarriers(with: snapshot, now: 0.1)
    #expect(node.zPosition > houseZ)
}
