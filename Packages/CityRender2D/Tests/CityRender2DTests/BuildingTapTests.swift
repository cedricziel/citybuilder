import CityCore
import SpriteKit
import Testing
@testable import CityRender2D

// rendering-2_5d / Input mapping (openspec/changes/tap-selects-building-sprite).

private func building(_ raw: UInt32, _ kind: BuildingKind, at x: Int, _ y: Int) -> Building {
    Building(id: EntityID(raw: raw), kind: kind, anchor: TileCoordinate(x: x, y: y), state: .operational)
}

/// A 12 × 12 meadow holding `buildings`, under a camera on (5, 5).
private func meadow(_ buildings: [Building]) -> WorldSnapshot {
    let base = World.fixtureWithTerrain(width: 12, height: 12, fill: .grass, seed: 1).snapshot()
    let occupied = buildings.flatMap { building in
        BuildingCatalog.spec(for: building.kind).footprint.tiles(anchor: building.anchor).map { ($0, building.id) }
    }
    return WorldSnapshot(
        tickCount: 180, simulatedTime: base.simulatedTime, mapWidth: 12, mapHeight: 12,
        terrainGrid: base.terrainGrid, occupiedTiles: Dictionary(uniqueKeysWithValues: occupied),
        buildings: Dictionary(uniqueKeysWithValues: buildings.map { ($0.id, $0) }), carriers: [],
        economy: base.economy, totalPopulation: 0, camera: Camera(centerX: 5, centerY: 5, zoom: 1)
    )
}

@MainActor
private func render(_ snapshot: WorldSnapshot, inspecting: Bool = true) -> IsoWorldScene {
    let scene = IsoWorldScene()
    scene.size = CGSize(width: 1024, height: 768)
    let source = FixedSnapshotSource(snapshot)
    scene.dataSource = source
    scene.userData = ["source": source]
    scene.inspectingProvider = { inspecting }
    scene.update(0)
    // Tests draw placeholder textures; a house's sprite is 144 x 112 pt in the app.
    for house in snapshot.buildings.values where house.kind == .house {
        scene.buildingNodes[house.anchor]?.size = CGSize(width: 144, height: 112)
    }
    return scene
}

@MainActor
private func tap(_ scene: IsoWorldScene, onTile tile: TileCoordinate) -> [Intent] {
    var sent: [Intent] = []
    scene.intentSink = { sent.append($0) }
    scene.handlePointerReleased(at: IsoMath.screenPoint(forTile: tile))
    return sent
}

/// A house at (5, 5) with a road along its back, on (5, 4) and (6, 4).
private let houseWithRoadBehind = meadow([
    building(1, .house, at: 5, 5), building(2, .road, at: 5, 4), building(3, .road, at: 6, 4)
])

@MainActor
@Test("scenario: Tapping a building's sprite selects it")
func tappingTheRoofSelectsTheHouse() {
    let scene = render(houseWithRoadBehind)
    #expect(tap(scene, onTile: TileCoordinate(x: 5, y: 4)) == [.tapTile(TileCoordinate(x: 5, y: 5))])
}

@MainActor
@Test("a tap on road the sprite leaves uncovered selects the road")
func aTapOnUncoveredRoadSelectsTheRoad() {
    let scene = render(meadow([building(1, .house, at: 5, 5), building(2, .road, at: 2, 7)]))
    #expect(tap(scene, onTile: TileCoordinate(x: 2, y: 7)) == [.tapTile(TileCoordinate(x: 2, y: 7))])
}

@MainActor
@Test("scenario: Other tools tap the tile behind a sprite")
func aTapUnderAnotherToolGoesToTheTile() {
    let scene = render(houseWithRoadBehind, inspecting: false)
    #expect(tap(scene, onTile: TileCoordinate(x: 5, y: 4)) == [.tapTile(TileCoordinate(x: 5, y: 4))])
}

@MainActor
@Test("scenario: The building in front takes an overlapping tap")
func theBuildingInFrontWins() {
    let scene = render(meadow([building(1, .house, at: 5, 3), building(2, .house, at: 5, 5)]))
    #expect(tap(scene, onTile: TileCoordinate(x: 5, y: 4)) == [.tapTile(TileCoordinate(x: 5, y: 5))])
}
