import CityCore
import SpriteKit
import Testing
@testable import CityRender2D

// Scenarios from openspec/changes/add-building-status-icons.

@MainActor
private final class FixedSnapshot: IsoWorldDataSource {
    var snapshot: WorldSnapshot
    init(_ snapshot: WorldSnapshot) {
        self.snapshot = snapshot
    }

    func currentSnapshot() -> WorldSnapshot? {
        snapshot
    }
}

private let anchor = TileCoordinate(x: 5, y: 5)
private let buildingID = EntityID(raw: 1)

private func town(
    _ kind: BuildingKind, tick: UInt64 = 180, issue: BuildingIssue? = nil, short: [Good] = [],
    roadless: Bool = false, owner: Owner = .player, zoom: Double = 1
) -> WorldSnapshot {
    let base = World.fixtureWithTerrain(width: 12, height: 12, fill: .grass, seed: 1).snapshot()
    let building = Building(id: buildingID, kind: kind, anchor: anchor, state: .operational, owner: owner)
    var pops: [EntityID: HousePopulation] = [:]
    if kind == .house {
        var pop = HousePopulation()
        pop.population = 4
        for good in short {
            pop.setShort(good, true)
        }
        pops[building.id] = pop
    }
    let tiles = BuildingCatalog.spec(for: kind).footprint.tiles(anchor: building.anchor)
    return WorldSnapshot(
        tickCount: tick, simulatedTime: base.simulatedTime, mapWidth: 12, mapHeight: 12,
        terrainGrid: base.terrainGrid, occupiedTiles: Dictionary(uniqueKeysWithValues: tiles.map { ($0, building.id) }),
        buildings: [building.id: building], carriers: [], economy: base.economy, totalPopulation: 0,
        camera: Camera(centerX: 5, centerY: 5, zoom: zoom),
        roadDisconnectedBuildings: roadless ? [building.id] : [],
        buildingIssues: issue.map { [building.id: $0] } ?? [:], housePopulations: pops
    )
}

@MainActor
private func render(_ snapshot: WorldSnapshot, reduceMotion: Bool = false) -> IsoWorldScene {
    let scene = IsoWorldScene()
    scene.size = CGSize(width: 1024, height: 768)
    scene.reduceMotion = reduceMotion
    let source = FixedSnapshot(snapshot)
    scene.dataSource = source
    scene.userData = ["source": source]
    scene.update(0)
    return scene
}

@MainActor
private func icon(in scene: IsoWorldScene) -> SKSpriteNode? {
    scene.buildingNodes[anchor]?.childNode(withName: StatusIcons.nodeName) as? SKSpriteNode
}

@MainActor
private func iconName(in scene: IsoWorldScene) -> String? {
    icon(in: scene)?.userData?[IsoWorldScene.textureNameKey] as? String
}

@MainActor
@Test("scenario: missing input shows the good")
func scenarioMissingInputShowsTheGood() {
    let scene = render(town(.bakery, issue: .missingInputs([.flour])))
    #expect(iconName(in: scene) == "status-flour-short")
    #expect(scene.buildingNodes[anchor]?.children.filter { $0.name == StatusIcons.nodeName }.count == 1)
}

@MainActor
@Test("scenario: a house short of a need shows the good")
func scenarioAHouseShortOfANeedShowsTheGood() {
    let scene = render(town(.house, short: [.beer, .bread]))
    #expect(iconName(in: scene) == "status-bread-short")
}

@MainActor
@Test("scenario: a working building shows no icon")
func scenarioAWorkingBuildingShowsNoIcon() {
    let scene = render(town(.sawmill))
    #expect(scene.buildingNodes[anchor] != nil)
    #expect(icon(in: scene) == nil)
}

@MainActor
@Test("scenario: the icon goes when the issue is fixed")
func scenarioTheIconGoesWhenTheIssueIsFixed() {
    let scene = render(town(.bakery, issue: .missingInputs([.flour])))
    (scene.dataSource as? FixedSnapshot)?.snapshot = town(.bakery, tick: 181)
    scene.update(0.1)
    #expect(icon(in: scene) == nil)
    #expect(scene.statusIcons.isEmpty)
}

@MainActor
@Test("a changed issue swaps the texture on the same node")
func aChangedIssueSwapsTheTexture() throws {
    let scene = render(town(.bakery, issue: .missingInputs([.flour])))
    let first = try #require(icon(in: scene))
    (scene.dataSource as? FixedSnapshot)?.snapshot = town(.bakery, tick: 181, issue: .storageFull)
    scene.update(0.1)
    #expect(icon(in: scene) === first)
    #expect(iconName(in: scene) == "status-storage-full")
}

@MainActor
@Test("scenario: Reduce Motion stills the icon")
func scenarioReduceMotionStillsTheIcon() throws {
    let stillScene = render(town(.bakery, issue: .missingInputs([.flour])), reduceMotion: true)
    let still = try #require(icon(in: stillScene))
    #expect(still.action(forKey: StatusIcons.bobKey) == nil)
    let movingScene = render(town(.bakery, issue: .missingInputs([.flour])))
    let moving = try #require(icon(in: movingScene))
    #expect(moving.action(forKey: StatusIcons.bobKey) != nil)
}

@MainActor
@Test("scenario: icon keeps three quarters of its size at zoom 0.5")
func scenarioIconKeepsThreeQuartersOfItsSizeAtZoomHalf() throws {
    let zoomedScene = render(town(.bakery, issue: .missingInputs([.flour]), zoom: 0.5))
    let zoomed = try #require(icon(in: zoomedScene))
    let disc = zoomed.size.width * 0.5 * StatusIcons.discFraction
    #expect(abs(disc - StatusIcons.discPoints * 0.75) < 0.01)
    let closeScene = render(town(.bakery, issue: .missingInputs([.flour]), zoom: 1))
    let close = try #require(icon(in: closeScene))
    #expect(abs(close.size.width * StatusIcons.discFraction - StatusIcons.discPoints) < 0.01)
}

@MainActor
@Test("scenario: disconnected building sprite carries the no-road marker")
func scenarioDisconnectedBuildingSpriteCarriesTheNoRoadMarker() {
    #expect(iconName(in: render(town(.warehouse, roadless: true))) == "status-no-road")
}

@MainActor
@Test("rival buildings show no status icon")
func rivalBuildingsShowNoStatusIcon() {
    #expect(icon(in: render(town(.house, short: [.bread], roadless: true, owner: .rival(0)))) == nil)
}

@MainActor
@Test("the icon draws above the night overlay")
func theIconDrawsAboveTheNightOverlay() throws {
    let scene = render(town(.bakery, tick: 780, issue: .missingInputs([.flour])))
    let node = try #require(scene.buildingNodes[anchor])
    let shown = try #require(icon(in: scene))
    #expect(node.zPosition + shown.zPosition > scene.nightOverlay.zPosition)
}

@MainActor
@Test("scenario: tapping the icon selects the building")
func scenarioTappingTheIconSelectsTheBuilding() throws {
    let scene = render(town(.bakery, issue: .missingInputs([.flour])))
    let shown = try #require(icon(in: scene))
    let centre = shown.convert(CGPoint(x: 0, y: shown.size.height / shown.yScale / 2), to: scene)
    #expect(scene.statusIconTile(at: centre) == anchor)
    #expect(scene.statusIconTile(at: CGPoint(x: centre.x + 200, y: centre.y)) == nil)
}

@Test("every issue maps to a drawn icon")
func everyIssueMapsToADrawnIcon() {
    let issues: [BuildingIssue] = [
        .noRoad, .noRouteToStorage, .noTreesInReach, .noRoomToPlant, .storageFull,
        .resting(.planks), .missingInputs([.wood, .iron])
    ]
    let names = issues.compactMap(StatusIcons.textureName(for:))
    #expect(names == [
        "status-no-road", "status-no-route", "status-no-trees", "status-no-room-to-plant", "status-storage-full",
        "status-planks-stuck", "status-wood-short"
    ])
    #expect(Set(names).isSubset(of: TextureFiltering.statusIcons))
}
