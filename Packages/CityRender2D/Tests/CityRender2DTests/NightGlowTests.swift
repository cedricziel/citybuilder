import CityCore
import SpriteKit
import Testing
@testable import CityRender2D

// Scenarios from openspec/changes/add-night-glow.

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

private func town(_ kind: BuildingKind, tick: UInt64, issue: BuildingIssue? = nil, residents: UInt32 = 0) -> WorldSnapshot {
    let base = World.fixtureWithTerrain(width: 12, height: 12, fill: .grass, seed: 1).snapshot()
    let building = Building(id: EntityID(raw: 1), kind: kind, anchor: TileCoordinate(x: 5, y: 5), state: .operational)
    var pops: [EntityID: HousePopulation] = [:]
    if residents > 0 {
        var pop = HousePopulation()
        pop.population = residents
        pops[building.id] = pop
    }
    let tiles = BuildingCatalog.spec(for: kind).footprint.tiles(anchor: building.anchor)
    return WorldSnapshot(
        tickCount: tick, simulatedTime: base.simulatedTime, mapWidth: 12, mapHeight: 12,
        terrainGrid: base.terrainGrid, occupiedTiles: Dictionary(uniqueKeysWithValues: tiles.map { ($0, building.id) }),
        buildings: [building.id: building], carriers: [], economy: base.economy, totalPopulation: 0,
        camera: Camera(centerX: 5, centerY: 5, zoom: 1),
        buildingIssues: issue.map { [building.id: $0] } ?? [:], housePopulations: pops
    )
}

@MainActor
private func render(_ snapshot: WorldSnapshot, hasSprite: @escaping (String) -> Bool = { _ in false }) -> (IsoWorldScene, SKNode?) {
    let scene = IsoWorldScene()
    scene.size = CGSize(width: 1024, height: 768)
    scene.hasSprite = hasSprite
    let source = FixedSnapshot(snapshot)
    scene.dataSource = source
    scene.userData = ["source": source]
    scene.update(0)
    return (scene, scene.buildingNodes[TileCoordinate(x: 5, y: 5)])
}

@MainActor
@Test("scenario: working forge glows at night")
func scenarioWorkingForgeGlowsAtNight() throws {
    let (_, node) = render(town(.toolsmith, tick: 780))
    let glow = try #require(node?.childNode(withName: FireGlow.nodeName))
    #expect(abs(glow.alpha - 1) < 0.001)
}

@MainActor
@Test("scenario: cold forge stays dark")
func scenarioColdForgeStaysDark() {
    let (_, node) = render(town(.toolsmith, tick: 780, issue: .missingInputs([.iron])))
    #expect(node != nil)
    #expect(node?.childNode(withName: FireGlow.nodeName) == nil)
}

@MainActor
@Test("scenario: no glow by day")
func scenarioNoGlowByDay() {
    let (_, node) = render(town(.toolsmith, tick: 180))
    #expect((node?.childNode(withName: FireGlow.nodeName)?.alpha ?? 0) == 0)
}

@MainActor
@Test("the glow leaves when the forge goes cold")
func glowLeavesWhenTheForgeGoesCold() {
    let (scene, node) = render(town(.toolsmith, tick: 780))
    (scene.dataSource as? FixedSnapshot)?.snapshot = town(.toolsmith, tick: 781, issue: .missingInputs([.iron]))
    scene.update(0.1)
    #expect(node?.childNode(withName: FireGlow.nodeName) == nil)
    #expect(scene.fireGlows.isEmpty)
}

@MainActor
@Test("scenario: lights mask replaces the panes")
func scenarioLightsMaskReplacesThePanes() throws {
    let (_, node) = render(town(.house, tick: 780, residents: 4)) { $0 == "building-house-lights" }
    let glow = try #require(node?.childNode(withName: IsoWorldScene.windowGlowNodeName) as? SKSpriteNode)
    #expect(glow.blendMode == .add && abs(glow.alpha - WindowLights.strength) < 0.001 && glow.children.isEmpty)
}

@MainActor
@Test("scenario: each house shows its own evening")
func houseShowsItsOwnVariant() {
    let variant = "building-house-lights-\(WindowLights.variant(for: EntityID(raw: 1)))"
    let (scene, node) = render(town(.house, tick: 780, residents: 4)) { $0 == variant || $0 == "building-house-lights" }
    #expect(node?.childNode(withName: IsoWorldScene.windowGlowNodeName) is SKSpriteNode)
    #expect(scene.lightsNames[variant] == .some(variant))
    let (single, _) = render(town(.house, tick: 780, residents: 4)) { $0 == "building-house-lights" }
    #expect(single.lightsNames[variant] == .some("building-house-lights"))
}

@MainActor
@Test("scenario: late at night most houses go to bed")
func lateNightHousesGoToBed() {
    // Tick 930 is 3 AM.
    let time = TimeOfDay(tick: 930)
    let expected = WindowLights.strength * CGFloat(time.darkness / TimeOfDay.nightDarkness)
        * (1 - WindowLights.sleepiness(of: EntityID(raw: 1), at: time))
    let (_, house) = render(town(.house, tick: 930, residents: 4)) { $0.hasPrefix("building-house-lights") }
    #expect(abs((house?.childNode(withName: IsoWorldScene.windowGlowNodeName)?.alpha ?? 0) - expected) < 0.001)
    let (_, bakery) = render(town(.bakery, tick: 930)) { $0.hasPrefix("building-bakery-lights") }
    let lit = bakery?.childNode(withName: IsoWorldScene.windowGlowNodeName)?.alpha ?? 0
    #expect(abs(lit - WindowLights.strength * CGFloat(time.darkness / TimeOfDay.nightDarkness)) < 0.001)
}

@MainActor
@Test("without lights art a house keeps its panes and a workshop stays dark")
func panesWithoutLightsArt() {
    let (_, house) = render(town(.house, tick: 780, residents: 4))
    #expect(house?.childNode(withName: IsoWorldScene.windowGlowNodeName)?.children.count == 2)
    let (_, bakery) = render(town(.bakery, tick: 780))
    #expect(bakery?.childNode(withName: IsoWorldScene.windowGlowNodeName) == nil)
    let (_, lit) = render(town(.bakery, tick: 780)) { $0 == "building-bakery-lights" }
    #expect(lit?.childNode(withName: IsoWorldScene.windowGlowNodeName) != nil)
}
