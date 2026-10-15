import CityCore
import SpriteKit
import Testing
@testable import CityRender2D

// Scenarios from openspec/changes/add-chimney-smoke.

private func operational(_ raw: UInt32, _ kind: BuildingKind, at x: Int, _ y: Int) -> Building {
    Building(id: EntityID(raw: raw), kind: kind, anchor: TileCoordinate(x: x, y: y), state: .operational)
}

private func residents(_ count: UInt32) -> HousePopulation {
    var pop = HousePopulation()
    pop.population = count
    return pop
}

private func snapshot(
    _ buildings: [Building],
    pops: [EntityID: HousePopulation] = [:],
    issues: [EntityID: BuildingIssue] = [:],
    camera: Camera = Camera(centerX: 10, centerY: 10, zoom: 1)
) -> WorldSnapshot {
    let base = World.fixtureWithTerrain(width: 20, height: 20, fill: .grass, seed: 1).snapshot()
    return WorldSnapshot(
        tickCount: 100, simulatedTime: base.simulatedTime, mapWidth: 20, mapHeight: 20,
        terrainGrid: base.terrainGrid, occupiedTiles: [:],
        buildings: Dictionary(uniqueKeysWithValues: buildings.map { ($0.id, $0) }),
        carriers: [], economy: base.economy, totalPopulation: 0, camera: camera,
        buildingIssues: issues, housePopulations: pops
    )
}

@Test("scenario: inhabited house smokes")
func scenarioInhabitedHouseSmokes() {
    let lived = operational(1, .house, at: 2, 2), empty = operational(2, .house, at: 5, 5)
    let sources = ChimneyPlanner.sources(in: snapshot([lived, empty], pops: [lived.id: residents(4), empty.id: residents(0)]))
    #expect(sources.map(\.id) == [lived.id])
    #expect(sources.first?.style == .smoke)
}

@Test("scenario: idle workshop is cold")
func scenarioIdleWorkshopIsCold() {
    let working = operational(1, .bakery, at: 2, 2), idle = operational(2, .bakery, at: 6, 6)
    let sources = ChimneyPlanner.sources(in: snapshot([working, idle], issues: [idle.id: .missingInputs([.flour])]))
    #expect(sources.map(\.id) == [working.id])
}

@Test("rival workshops stay cold; rival houses still smoke")
func rivalWorkshopsStayCold() {
    let bakery = Building(
        id: EntityID(raw: 1), kind: .bakery, anchor: TileCoordinate(x: 2, y: 2), state: .operational, owner: .rival(1)
    )
    let house = Building(
        id: EntityID(raw: 2), kind: .house, anchor: TileCoordinate(x: 6, y: 6), state: .operational, owner: .rival(1)
    )
    #expect(ChimneyPlanner.sources(in: snapshot([bakery, house], pops: [house.id: residents(3)])).map(\.id) == [house.id])
}

@Test("scenario: brewery steams")
func scenarioBrewerySteams() {
    let brewery = operational(1, .brewery, at: 2, 2)
    #expect(ChimneyPlanner.sources(in: snapshot([brewery])).map(\.style) == [.steam])
}

@Test("buildings under construction and other trades do not smoke")
func constructionAndColdTradesDoNotSmoke() {
    var site = operational(1, .smelter, at: 2, 2)
    site.state = .constructing
    let farm = operational(2, .farm, at: 6, 6)
    #expect(ChimneyPlanner.sources(in: snapshot([site, farm])).isEmpty)
}

@Test("scenario: smoke budget follows zoom")
func scenarioSmokeBudgetFollowsZoom() {
    var buildings: [Building] = []
    var pops: [EntityID: HousePopulation] = [:]
    for index in 0 ..< 60 {
        let house = operational(UInt32(index + 1), .house, at: index % 10 * 2, index / 10 * 2)
        buildings.append(house)
        pops[house.id] = residents(3)
    }
    let bakeries = [operational(100, .bakery, at: 19, 18), operational(101, .bakery, at: 18, 19)]
    let camera = Camera(centerX: 0, centerY: 0, zoom: 0.5)
    let snap = snapshot(buildings + bakeries, pops: pops, camera: camera)
    let chosen = ChimneyPlanner.select(
        ChimneyPlanner.sources(in: snap), xRange: 0 ... 19, yRange: 0 ... 19, camera: camera
    )
    #expect(chosen.count == 12)
    #expect(Set(bakeries.map(\.id)).isSubset(of: Set(chosen.map(\.id))))
}

@Test("the budget is clamped between 8 and 40")
func budgetIsClamped() {
    #expect(ChimneyPlanner.budget(zoom: 0.25) == 8)
    #expect(ChimneyPlanner.budget(zoom: 1) == 24)
    #expect(ChimneyPlanner.budget(zoom: 4) == 40)
}

@Test("sources outside the visible range are culled")
func offscreenSourcesAreCulled() {
    let near = operational(1, .bakery, at: 2, 2), far = operational(2, .bakery, at: 15, 15)
    let chosen = ChimneyPlanner.select(
        ChimneyPlanner.sources(in: snapshot([near, far])), xRange: 0 ... 5, yRange: 0 ... 5, camera: Camera()
    )
    #expect(chosen.map(\.id) == [near.id])
}

@MainActor
@Test("scenario: reduce motion slows smoke")
func scenarioReduceMotionSlowsSmoke() throws {
    let source = SmokeSource(id: EntityID(raw: 1), anchor: TileCoordinate(x: 0, y: 0), kind: .house, style: .smoke)
    let layer = AmbientLayerNode()
    layer.show([(source, .zero)], reduceMotion: false)
    let normal = try #require(layer.emitter(for: source.id))
    let normalRate = normal.particleBirthRate, normalSpeed = normal.particleSpeed
    layer.show([(source, .zero)], reduceMotion: true)
    let reduced = try #require(layer.emitter(for: source.id))
    #expect(abs(reduced.particleBirthRate - normalRate / 2) < 0.001)
    #expect(abs(reduced.particleSpeed - normalSpeed / 2) < 0.001)
}

@MainActor
@Test("emitters return to the pool and are reused")
func emittersArePooled() throws {
    let first = SmokeSource(id: EntityID(raw: 1), anchor: TileCoordinate(x: 0, y: 0), kind: .house, style: .smoke)
    let second = SmokeSource(id: EntityID(raw: 2), anchor: TileCoordinate(x: 1, y: 0), kind: .bakery, style: .smoke)
    let layer = AmbientLayerNode()
    layer.show([(first, .zero)], reduceMotion: false)
    let emitter = try #require(layer.emitter(for: first.id))
    layer.show([], reduceMotion: false)
    #expect(layer.emitterCount == 0)
    #expect(emitter.particleBirthRate == 0)
    #expect(emitter.parent === layer, "a removed plume fades before it leaves")
    layer.recycle(emitter)
    layer.show([(second, CGPoint(x: 5, y: 5))], reduceMotion: false)
    #expect(layer.emitter(for: second.id) === emitter)
    #expect(emitter.position == CGPoint(x: 5, y: 5))
}

@Test("chimney anchors sit inside the sprite and fall back to the roof")
func chimneyAnchorsSitInsideTheSprite() {
    let size = CGSize(width: 128, height: 128)
    let bakery = ChimneyAnchors.offset(stem: "building-bakery", spriteSize: size)
    #expect(bakery.x > 0 && bakery.y > 64 && bakery.y < 128)
    let unknown = ChimneyAnchors.offset(stem: "building-mead-hall", spriteSize: size)
    #expect(unknown.x == 0 && unknown.y > 100)
    let variant = ChimneyAnchors.offset(stem: "building-house-tier2-modern-east-asian", spriteSize: size)
    #expect(variant == ChimneyAnchors.offset(stem: "building-house-tier2", spriteSize: size))
    #expect(TextureFiltering.stem(of: "building-house-tier2") == "building-house-tier2")
}

/// Every house and fire-trade sprite in the atlases finds a table row,
/// directly or through its base stem, unless listed here as using the
/// roof fallback on purpose.
@Test("every smoking sprite has a chimney row")
func everySmokingSpriteHasAChimneyRow() throws {
    let resources = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Resources")
    let prefixes = [
        "building-house",
        "building-bakery",
        "building-brewery",
        "building-smelter",
        "building-toolsmith",
        "building-charcoal-burner"
    ]
    let rooflessOnPurpose: Set<String> = []
    var stems: Set<String> = []
    for atlas in ["Kit.atlas", "Buildings.atlas"] {
        let files = try FileManager.default.contentsOfDirectory(atPath: resources.appendingPathComponent(atlas).path)
        for file in files where file.hasSuffix(".png") && !file.contains("-constructing") {
            let name = String(file.dropLast(4)).replacingOccurrences(of: "@2x", with: "")
            if prefixes.contains(where: name.hasPrefix) { stems.insert(TextureFiltering.stem(of: name)) }
        }
    }
    #expect(stems.count > 20)
    let missing = stems.filter { ChimneyAnchors.row(for: $0) == nil && !rooflessOnPurpose.contains($0) }
    #expect(missing.isEmpty, "no chimney row for \(missing.sorted())")
}
