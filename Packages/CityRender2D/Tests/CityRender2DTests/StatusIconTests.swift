import CityCore
import SpriteKit
import Testing
@testable import CityRender2D

// Scenarios from openspec/changes/add-building-status-icons.

private let anchor = TileCoordinate(x: 5, y: 5)
private let buildingID = EntityID(raw: 1)

/// An inhabited house short of `goods`.
private func household(short goods: [Good], tier: HouseTier = .peasants) -> HousePopulation {
    var pop = HousePopulation()
    pop.population = 4
    pop.tier = tier
    for good in goods {
        pop.setShort(good, true)
    }
    return pop
}

/// A 12 × 12 meadow holding `buildings`, under a camera on (5, 5).
private func meadow(
    _ buildings: [Building], tick: UInt64 = 180, issues: [EntityID: BuildingIssue] = [:],
    households: [EntityID: HousePopulation] = [:], roadless: Set<EntityID> = [], zoom: Double = 1
) -> WorldSnapshot {
    let base = World.fixtureWithTerrain(width: 12, height: 12, fill: .grass, seed: 1).snapshot()
    let occupied = buildings.flatMap { building in
        BuildingCatalog.spec(for: building.kind).footprint.tiles(anchor: building.anchor).map { ($0, building.id) }
    }
    return WorldSnapshot(
        tickCount: tick, simulatedTime: base.simulatedTime, mapWidth: 12, mapHeight: 12,
        terrainGrid: base.terrainGrid, occupiedTiles: Dictionary(uniqueKeysWithValues: occupied),
        buildings: Dictionary(uniqueKeysWithValues: buildings.map { ($0.id, $0) }), carriers: [],
        economy: base.economy, totalPopulation: 0, camera: Camera(centerX: 5, centerY: 5, zoom: zoom),
        roadDisconnectedBuildings: roadless, buildingIssues: issues, housePopulations: households
    )
}

/// One building of `kind` at (5, 5).
private func town(
    _ kind: BuildingKind, tick: UInt64 = 180, issue: BuildingIssue? = nil, short: [Good] = [],
    roadless: Bool = false, owner: Owner = .player, zoom: Double = 1, tier: HouseTier = .peasants
) -> WorldSnapshot {
    let building = Building(id: buildingID, kind: kind, anchor: anchor, state: .operational, owner: owner)
    return meadow(
        [building], tick: tick, issues: issue.map { [buildingID: $0] } ?? [:],
        households: kind == .house ? [buildingID: household(short: short, tier: tier)] : [:],
        roadless: roadless ? [buildingID] : [], zoom: zoom
    )
}

@MainActor
private func render(_ snapshot: WorldSnapshot, reduceMotion: Bool = false) -> IsoWorldScene {
    let scene = IsoWorldScene()
    scene.size = CGSize(width: 1024, height: 768)
    scene.reduceMotion = reduceMotion
    let source = FixedSnapshotSource(snapshot)
    scene.dataSource = source
    scene.userData = ["source": source]
    scene.update(0)
    return scene
}

/// Hands the scene `snapshot` and runs one more frame.
@MainActor
private func advance(_ scene: IsoWorldScene, to snapshot: WorldSnapshot) throws {
    try #require(scene.dataSource as? FixedSnapshotSource).snapshot = snapshot
    scene.update(0.1)
}

@MainActor
private func icon(in scene: IsoWorldScene, at tile: TileCoordinate = anchor) -> SKSpriteNode? {
    scene.buildingNodes[tile]?.childNode(withName: StatusIcons.nodeName) as? SKSpriteNode
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
func scenarioTheIconGoesWhenTheIssueIsFixed() throws {
    let scene = render(town(.bakery, issue: .missingInputs([.flour])))
    try advance(scene, to: town(.bakery, tick: 181))
    #expect(icon(in: scene) == nil)
    #expect(scene.statusIcons.isEmpty)
}

@MainActor
@Test("a changed issue swaps the texture on the same node")
func aChangedIssueSwapsTheTexture() throws {
    let scene = render(town(.bakery, issue: .missingInputs([.flour])))
    let first = try #require(icon(in: scene))
    try advance(scene, to: town(.bakery, tick: 181, issue: .outputStuck(.bread)))
    #expect(icon(in: scene) === first)
    #expect(iconName(in: scene) == "status-bread-stuck")
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
    let centre = try iconCentre(in: scene)
    #expect(scene.statusIconTile(at: centre) == anchor)
    #expect(scene.statusIconTile(at: CGPoint(x: centre.x + 200, y: centre.y)) == nil)
    scene.inspectingProvider = { true }
    #expect(tap(scene, at: centre) == [.tapTile(anchor)])
}

@MainActor
private func iconCentre(in scene: IsoWorldScene, at tile: TileCoordinate = anchor) throws -> CGPoint {
    let shown = try #require(icon(in: scene, at: tile))
    return shown.convert(CGPoint(x: 0, y: shown.size.height / shown.yScale / 2), to: scene)
}

@MainActor
private func tap(_ scene: IsoWorldScene, at location: CGPoint) -> [Intent] {
    var sent: [Intent] = []
    scene.intentSink = { sent.append($0) }
    scene.handlePointerReleased(at: location)
    return sent
}

/// A point on the icon whose own tile is not the building's anchor, so a redirect shows.
@MainActor
private func offAnchorSpot(on scene: IsoWorldScene, near centre: CGPoint) -> CGPoint? {
    for dx in stride(from: -20, through: 20, by: 4) {
        for dy in stride(from: -20, through: 20, by: 4) {
            let spot = CGPoint(x: centre.x + CGFloat(dx), y: centre.y + CGFloat(dy))
            let tile = InputTranslator.tile(atScreenPoint: spot, mapWidth: 12, mapHeight: 12)
            if scene.statusIconTile(at: spot) == anchor, tile != anchor { return spot }
        }
    }
    return nil
}

@MainActor
@Test("a tap under Demolish or a place tool goes to the tile, not the icon's building")
func aTapUnderAnotherToolIsNotRedirected() throws {
    let scene = render(town(.bakery, issue: .missingInputs([.flour])))
    let centre = try iconCentre(in: scene)
    let spot = try #require(offAnchorSpot(on: scene, near: centre))
    let underneath = try #require(InputTranslator.tile(atScreenPoint: spot, mapWidth: 12, mapHeight: 12))
    scene.inspectingProvider = { false }
    #expect(tap(scene, at: spot) == [.tapTile(underneath)])
    scene.inspectingProvider = nil
    #expect(tap(scene, at: spot) == [.tapTile(underneath)])
    scene.inspectingProvider = { true }
    #expect(tap(scene, at: spot) == [.tapTile(anchor)])
}

/// Two neighbouring houses short of bread, at zoom 0.5, where their hit areas overlap.
private func neighbours() -> WorldSnapshot {
    let houses = [5, 7]
        .map { Building(id: EntityID(raw: UInt32($0)), kind: .house, anchor: TileCoordinate(x: $0, y: 5), state: .operational) }
    let bread = household(short: [.bread])
    return meadow(houses, households: Dictionary(uniqueKeysWithValues: houses.map { ($0.id, bread) }), zoom: 0.5)
}

@MainActor
@Test("where hit areas overlap, the icon nearest the tap wins")
func whereHitAreasOverlapTheNearestIconWins() throws {
    let scene = render(neighbours())
    let first = TileCoordinate(x: 5, y: 5), second = TileCoordinate(x: 7, y: 5)
    let left = try iconCentre(in: scene, at: first), right = try iconCentre(in: scene, at: second)
    // Both 44 pt hit areas cover the midpoint at zoom 0.5; a nudge either way picks that side.
    let mid = CGPoint(x: (left.x + right.x) / 2, y: (left.y + right.y) / 2)
    let step = CGPoint(x: (right.x - left.x) / 8, y: (right.y - left.y) / 8)
    #expect(scene.statusIconTile(at: CGPoint(x: mid.x - step.x, y: mid.y - step.y)) == first)
    #expect(scene.statusIconTile(at: CGPoint(x: mid.x + step.x, y: mid.y + step.y)) == second)
    #expect(scene.statusIconTile(at: left) == first)
    #expect(scene.statusIconTile(at: right) == second)
}

@MainActor
@Test("a demolished building's icon leaves the scene")
func aDemolishedBuildingsIconLeaves() throws {
    let scene = render(town(.bakery, issue: .missingInputs([.flour])))
    try advance(scene, to: meadow([], tick: 181))
    #expect(scene.statusIcons.isEmpty)
}

@MainActor
@Test("the icon moves to the new sprite when the building's node is replaced")
func theIconReparentsWhenItsSpriteIsReplaced() throws {
    let scene = render(town(.house, short: [.bread]))
    let old = try #require(scene.buildingNodes[anchor])
    try advance(scene, to: town(.house, tick: 181, short: [.bread], tier: .citizens))
    let new = try #require(scene.buildingNodes[anchor])
    #expect(new !== old)
    #expect(icon(in: scene)?.parent === new)
    #expect(scene.statusIcons.count == 1)
}

@MainActor
@Test("a zoom change rescales an existing icon")
func aZoomChangeRescalesAnExistingIcon() throws {
    let scene = render(town(.bakery, issue: .missingInputs([.flour])))
    let first = try #require(icon(in: scene))
    try advance(scene, to: town(.bakery, tick: 181, issue: .missingInputs([.flour]), zoom: 0.5))
    #expect(icon(in: scene) === first)
    #expect(abs(first.xScale - 1.5) < 0.001)
}

@MainActor
@Test("turning Reduce Motion on stops a running bob")
func turningReduceMotionOnStopsTheBob() throws {
    let scene = render(town(.bakery, issue: .missingInputs([.flour])))
    let shown = try #require(icon(in: scene))
    #expect(shown.action(forKey: StatusIcons.bobKey) != nil)
    scene.reduceMotion = true
    scene.update(0.1)
    #expect(shown.action(forKey: StatusIcons.bobKey) == nil)
}

@Test("an empty missing-inputs issue keeps the building's other icon")
func anEmptyMissingInputsIssueKeepsTheOtherIcon() {
    #expect(StatusIcons.textureName(for: .missingInputs([])) == nil)
    let snapshot = town(.warehouse, issue: .missingInputs([]), roadless: true)
    #expect(StatusIcons.icons(in: snapshot)[buildingID] == "status-no-road")
}

@Test("every issue maps to a drawn icon")
func everyIssueMapsToADrawnIcon() {
    let issues: [BuildingIssue] = [
        .noRoad, .noRouteToStorage, .noTreesInReach, .noRoomToPlant,
        .outputStuck(.planks), .missingInputs([.wood, .iron])
    ]
    let names = issues.compactMap(StatusIcons.textureName(for:))
    #expect(names == [
        "status-no-road", "status-no-route", "status-no-trees", "status-no-room-to-plant",
        "status-planks-stuck", "status-wood-short"
    ])
    #expect(Set(names).isSubset(of: TextureFiltering.statusIcons))
}

@Test("the icon sits on the sprite's opaque top, not on its cell's headroom")
func theIconSitsOnTheOpaqueTop() throws {
    let width = 4, height = 10
    let context = try #require(CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ))
    // Opaque bottom 6 rows (CoreGraphics' origin is bottom-left), clear headroom above.
    context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: 6))
    let image = try #require(context.makeImage())
    #expect(abs(StatusIcons.measureContentTop(image) - 0.6) < 0.001)
}
