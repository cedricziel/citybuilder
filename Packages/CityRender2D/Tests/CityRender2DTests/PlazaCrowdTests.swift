import CityCore
import SpriteKit
import Testing
@testable import CityRender2D

// Scenarios from openspec/changes/add-plaza-crowd.

private let center = Building(id: EntityID(raw: 1), kind: .townCenter, anchor: TileCoordinate(x: 8, y: 8), state: .operational)

private func town(residents: UInt32, tick: UInt64, zoom: Double = 1, festival: Bool = false) -> WorldSnapshot {
    let base = World.fixtureWithTerrain(width: 30, height: 30, fill: .grass, seed: 1).snapshot()
    var buildings = [center.id: center]
    var pops: [EntityID: HousePopulation] = [:]
    for index in 0 ..< 3 {
        let house = Building(
            id: EntityID(raw: UInt32(10 + index)), kind: .house, anchor: TileCoordinate(x: 3 + index * 2, y: 3), state: .operational
        )
        buildings[house.id] = house
        var pop = HousePopulation()
        pop.population = residents / 3
        pops[house.id] = pop
    }
    // A house beyond 12 tiles does not count.
    let far = Building(id: EntityID(raw: 20), kind: .house, anchor: TileCoordinate(x: 25, y: 25), state: .operational)
    buildings[far.id] = far
    var farPop = HousePopulation()
    farPop.population = 30
    pops[far.id] = farPop
    return WorldSnapshot(
        tickCount: tick, simulatedTime: base.simulatedTime, mapWidth: 30, mapHeight: 30,
        terrainGrid: base.terrainGrid, occupiedTiles: [:], buildings: buildings, carriers: [],
        economy: base.economy, totalPopulation: 0, camera: Camera(centerX: 8, centerY: 8, zoom: zoom),
        housePopulations: pops, isFestivalCrowd: festival
    )
}

private func plan(_ snapshot: WorldSnapshot, reduceMotion: Bool = false) -> [PlazaCrowdPlanner.Figure] {
    PlazaCrowdPlanner.figures(in: snapshot, xRange: 0 ... 29, yRange: 0 ... 29, reduceMotion: reduceMotion)
}

@Test("scenario: busy plaza by day")
func scenarioBusyPlazaByDay() {
    #expect(plan(town(residents: 30, tick: 180)).count == 8)
    #expect(plan(town(residents: 9, tick: 180)).count == 3)
}

@Test("scenario: a festival crowd fills the plaza")
func festivalCrowdFillsThePlaza() {
    let spots = PlazaLayout.northernEuropean.lanes.joined().count
    let crowd = plan(town(residents: 3, tick: 180, festival: true))
    #expect(crowd.count == spots)
    #expect(Set(crowd.map { PlazaFigureKey(townCenter: $0.townCenter, slot: $0.slot) }).count == spots)
}

@Test("scenario: empty plaza at night")
func scenarioEmptyPlazaAtNight() {
    #expect(plan(town(residents: 30, tick: 780)).isEmpty)
}

@Test("no crowd when zoomed far out or off screen")
func noCrowdZoomedOutOrOffscreen() {
    #expect(plan(town(residents: 30, tick: 180, zoom: 0.4)).isEmpty)
    let snapshot = town(residents: 30, tick: 180)
    #expect(PlazaCrowdPlanner.figures(in: snapshot, xRange: 0 ... 5, yRange: 0 ... 5, reduceMotion: false).isEmpty)
}

@Test("scenario: figures stay on the plaza")
func scenarioFiguresStayOnThePlaza() {
    let layout = PlazaLayout.northernEuropean
    var walked = false
    for tick in stride(from: UInt64(0), to: TimeOfDay.ticksPerDay, by: 7) {
        for figure in plan(town(residents: 30, tick: tick)) {
            let spot = (u: figure.col - Double(center.anchor.x) + 0.5, v: figure.row - Double(center.anchor.y) + 0.5)
            #expect((0 ... 3).contains(spot.u) && (0 ... 3).contains(spot.v))
            #expect(!layout.props.contains { $0.contains(spot) }, "figure inside a prop at \(spot)")
            walked = walked || figure.walking
        }
    }
    #expect(walked)
}

@Test("no spot or walk inside a lane crosses a prop or passes behind one", arguments: [PlazaLayout.northernEuropean, PlazaLayout.rim])
func lanesKeepClearOfProps(layout: PlazaLayout) {
    for lane in layout.lanes {
        for from in lane {
            for to in lane {
                for step in 0 ... 20 {
                    let along = Double(step) / 20
                    let spot = (u: from.u + (to.u - from.u) * along, v: from.v + (to.v - from.v) * along)
                    let hit = layout.props.first { $0.contains(spot) }
                    #expect(hit == nil, "walk \(from) → \(to) crosses \(hit?.name ?? "")")
                    let cover = layout.props.first { $0.hides(spot) }
                    #expect(cover == nil, "walk \(from) → \(to) passes behind \(cover?.name ?? "")")
                }
            }
        }
    }
}

@Test("culture town centers use the paved rim")
func cultureTownCentersUseTheRim() {
    var snapshot = town(residents: 30, tick: 180)
    snapshot = WorldSnapshot(
        tickCount: snapshot.tickCount, simulatedTime: snapshot.simulatedTime, mapWidth: 30, mapHeight: 30,
        terrainGrid: snapshot.terrainGrid, occupiedTiles: [:], buildings: snapshot.buildings, carriers: [],
        economy: snapshot.economy, totalPopulation: 0, camera: snapshot.camera,
        housePopulations: snapshot.housePopulations, culture: .eastAsian
    )
    for figure in plan(snapshot) {
        let spot = (u: figure.col - Double(center.anchor.x) + 0.5, v: figure.row - Double(center.anchor.y) + 0.5)
        #expect(spot.u > 2.75 || spot.v > 2.75)
    }
}

@Test("two town centers each get their own crowd")
func twoTownCenters() {
    let base = town(residents: 30, tick: 180)
    let second = Building(id: EntityID(raw: 2), kind: .townCenter, anchor: TileCoordinate(x: 24, y: 24), state: .operational)
    var buildings = base.buildings
    buildings[second.id] = second
    let snapshot = WorldSnapshot(
        tickCount: 180, simulatedTime: base.simulatedTime, mapWidth: 30, mapHeight: 30,
        terrainGrid: base.terrainGrid, occupiedTiles: [:], buildings: buildings, carriers: [],
        economy: base.economy, totalPopulation: 0, camera: base.camera, housePopulations: base.housePopulations
    )
    let figures = plan(snapshot)
    // The far house (30 residents) sits next to the second town center only.
    #expect(figures.count { $0.townCenter == center.id } == 8)
    #expect(figures.count { $0.townCenter == second.id } == 8)
    #expect(figures.filter { $0.townCenter == second.id }.allSatisfy { $0.col > 20 && $0.row > 20 })
}

@MainActor
@Test("plaza nodes follow the head count, night and zoom")
func plazaNodeLifecycle() throws {
    let scene = IsoWorldScene()
    scene.size = CGSize(width: 1024, height: 768)
    scene.reconcilePlazaCrowd(with: town(residents: 30, tick: 180), now: 0)
    #expect(scene.plazaNodes.count == 8)
    let dropped = try #require(scene.plazaNodes[PlazaFigureKey(townCenter: center.id, slot: 7)]?.node)
    #expect(dropped.zPosition > IsoWorldScene.depthZ(19) && dropped.zPosition < IsoWorldScene.depthZ(19.5))
    scene.reconcilePlazaCrowd(with: town(residents: 9, tick: 181), now: 0.1)
    #expect(scene.plazaNodes.count == 3 && dropped.parent == nil)
    scene.reconcilePlazaCrowd(with: town(residents: 30, tick: 780), now: 0.2)
    #expect(scene.plazaNodes.isEmpty)
    scene.reconcilePlazaCrowd(with: town(residents: 30, tick: 182), now: 0.3)
    #expect(scene.plazaNodes.count == 8)
    scene.reconcilePlazaCrowd(with: town(residents: 30, tick: 183, zoom: 0.4), now: 0.4)
    #expect(scene.plazaNodes.isEmpty)
}

@MainActor
@Test("plaza figures stand on their feet, unmirrored")
func plazaNodesStandOnTheirFeet() {
    let scene = IsoWorldScene()
    scene.size = CGSize(width: 1024, height: 768)
    scene.reconcilePlazaCrowd(with: town(residents: 30, tick: 180), now: 0)
    #expect(!scene.plazaNodes.isEmpty)
    for shown in scene.plazaNodes.values {
        #expect(abs(shown.node.anchorPoint.x - SpriteAtlas.walkerAnchor.x) < 0.0001)
        #expect(abs(shown.node.anchorPoint.y - SpriteAtlas.walkerAnchor.y) < 0.0001)
        #expect(shown.node.xScale > 0)
    }
}

@MainActor
@Test("a paused game stops walk cycles")
func pausedGameStopsWalking() {
    let scene = IsoWorldScene()
    scene.size = CGSize(width: 1024, height: 768)
    // Find a tick where some figure walks.
    let tick = (UInt64(150) ..< 400).first { tick in plan(town(residents: 30, tick: tick)).contains(where: \.walking) } ?? 150
    scene.reconcilePlazaCrowd(with: town(residents: 30, tick: tick), now: 0)
    #expect(scene.plazaNodes.values.contains { $0.pose.walking })
    scene.reconcilePlazaCrowd(with: town(residents: 30, tick: tick), now: 1)
    #expect(scene.plazaNodes.values.allSatisfy { !$0.pose.walking })
}

@Test("scenario: reduce motion keeps figures still")
func scenarioReduceMotionKeepsFiguresStill() {
    let early = plan(town(residents: 30, tick: 100), reduceMotion: true)
    let later = plan(town(residents: 30, tick: 400), reduceMotion: true)
    #expect(early.map(\.col) == later.map(\.col) && early.map(\.row) == later.map(\.row))
    #expect(early.allSatisfy { !$0.walking })
}

@Test("figures of one plaza are spread out and stable per tick")
func figuresAreSpreadAndStable() {
    let first = plan(town(residents: 30, tick: 200))
    #expect(Set(first.map { "\($0.col),\($0.row)" }).count == first.count)
    #expect(plan(town(residents: 30, tick: 200)) == first)
}

@Test("every lane has a spot for each figure it gets", arguments: [PlazaLayout.northernEuropean, PlazaLayout.rim])
func lanesHoldTheirFigures(layout: PlazaLayout) {
    for (index, lane) in layout.lanes.enumerated() {
        let figures = (0 ..< PlazaCrowdPlanner.maxPerPlaza).count { $0 % layout.lanes.count == index }
        #expect(lane.count >= figures)
    }
}

@MainActor
@Test("scenario: a mixed crowd")
func scenarioAMixedCrowd() {
    let looks = (0 ..< PlazaCrowdPlanner.maxPerPlaza).map { PlazaCrowdPlanner.look(center: center.id, slot: $0) }
    #expect(Set(looks) == Set(SpriteAtlas.WalkerLook.allCases))
    #expect(looks == (0 ..< PlazaCrowdPlanner.maxPerPlaza).map { PlazaCrowdPlanner.look(center: center.id, slot: $0) })
    let scene = IsoWorldScene()
    scene.size = CGSize(width: 1024, height: 768)
    scene.reconcilePlazaCrowd(with: town(residents: 30, tick: 180), now: 0)
    #expect(scene.plazaNodes.count == 8)
    #expect(scene.plazaNodes.allSatisfy { key, shown in
        shown.node.colorBlendFactor == 0 && shown.pose.look == PlazaCrowdPlanner.look(center: key.townCenter, slot: key.slot)
    })
}

@Test("a tall prop hides what stands behind it, not what stands in front")
func propsHideOnlyWhatIsBehind() {
    let stall = PlazaLayout.Prop(name: "stall", alongU: 1 ... 1.5, alongV: 1 ... 1.5)
    #expect(stall.hides((u: 0.9, v: 0.9)))
    #expect(!stall.hides((u: 1.7, v: 1.7)))
    #expect(!stall.hides((u: 0.5, v: 2.5)), "beside it, in another screen column")
    #expect(!PlazaLayout.Prop(name: "crate", alongU: 1 ... 1.5, alongV: 1 ... 1.5, tall: false).hides((u: 0.9, v: 0.9)))
}
