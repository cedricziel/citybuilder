import Foundation
import Testing
@testable import CityCore
@testable import CityUI

// Scenarios from openspec/changes/add-areas-of-effect: rendering-2_5d / Areas of effect while
// placing and selecting, and platform-shells / Count capsule over the ghost.

/// The first anchor on the new-game map where the player may place `kind` and it would reach
/// `count` tiles.
private func site(for kind: BuildingKind, reaching count: Int, in world: World) throws -> TileCoordinate {
    let tiles = (0 ..< world.mapHeight).lazy.flatMap { y in (0 ..< world.mapWidth).lazy.map { TileCoordinate(x: $0, y: y) } }
    return try #require(tiles.first { tile in
        guard case .allowed = world.canPlace(kind, at: tile) else { return false }
        return world.catchmentCount(kind: kind, anchor: tile, owner: .player) == count
    })
}

@MainActor
@Test("the ghost's area is what its site reaches")
func ghostAreaIsItsSite() throws {
    let session = GameSession()
    let anchor = try site(for: .lumberjackHut, reaching: 9, in: session.world)
    session.selectTool(.place(.lumberjackHut))
    session.handleHover(at: anchor)
    let area = try #require(session.areaOfEffect())
    #expect(area == session.world.areaOfEffect(of: .lumberjackHut, at: anchor, placing: true))
    #expect(area.count == 9)
}

@MainActor
@Test("scenario: a selected hut shows its catchment")
func selectedHutShowsItsArea() throws {
    let session = GameSession()
    let anchor = try site(for: .lumberjackHut, reaching: 9, in: session.world)
    session.world.enqueue(.place(.lumberjackHut, at: anchor))
    session.world.tick()
    session.selectedTile = TileCoordinate(x: anchor.x + 1, y: anchor.y + 1)
    let area = try #require(session.areaOfEffect())
    #expect(area == session.world.areaOfEffect(of: .lumberjackHut, at: anchor, placing: false))
    // The inspector shows a selected building's count, so no capsule.
    #expect(session.areaCountCapsule == nil)
}

@MainActor
@Test("no area for an empty selection or a plain building")
func noAreaWithoutAReach() {
    let session = GameSession()
    session.selectedTile = TileCoordinate(x: 0, y: 0)
    #expect(session.areaOfEffect() == nil)
    session.selectTool(.place(.house))
    session.handleHover(at: session.world.camera.centerTile())
    #expect(session.areaOfEffect() == nil)
}

@MainActor
@Test("scenario: enough trees reads neutral")
func capsuleOverAValidGhost() throws {
    let session = GameSession()
    let anchor = try site(for: .lumberjackHut, reaching: 9, in: session.world)
    session.selectTool(.place(.lumberjackHut))
    session.handleHover(at: anchor)
    #expect(session.areaCountCapsule == AreaCountCapsuleModel(
        text: "9 trees in reach", tone: .neutral, kind: .lumberjackHut, anchor: anchor
    ))
}

@MainActor
@Test("no area and no capsule where the ghost could not be placed")
func nothingOverAnInvalidGhost() throws {
    let session = GameSession()
    let center = try #require(session.world.buildings.values.first { $0.kind == .townCenter })
    session.selectTool(.place(.lumberjackHut))
    session.handleHover(at: center.anchor)
    #expect(session.areaOfEffect() == nil)
    #expect(session.areaCountCapsule == nil)
}

@MainActor
@Test("the area is asked again on a new tick")
func areaCacheFollowsTheTick() throws {
    let session = GameSession()
    let anchor = try site(for: .lumberjackHut, reaching: 9, in: session.world)
    session.selectTool(.place(.lumberjackHut))
    session.handleHover(at: anchor)
    let before = try #require(session.areaOfEffect())
    // Open grass in the catchment turns to forest without a tick: the cached area stands.
    let grass = try #require(before.tiles.sorted { ($0.y, $0.x) < ($1.y, $1.x) }.first { tile in
        session.world.terrain(at: tile) == .grass && session.world.occupiedTiles[tile] == nil
            && !BuildingCatalog.spec(for: .lumberjackHut).footprint.tiles(anchor: anchor).contains(tile)
    })
    session.world.terrainGrid[grass.y * session.world.mapWidth + grass.x] = .forest
    #expect(session.areaOfEffect() == before)
    session.world.tick()
    let after = try #require(session.areaOfEffect())
    #expect(after.count == 10)
    #expect(after.targets.contains(grass))
}

@Test("scenario: few trees read amber, none read red")
func capsuleTextAndTones() {
    #expect(AreaCountCapsuleModel.text(kind: .lumberjackHut, count: 18) == "18 trees in reach")
    #expect(AreaCountCapsuleModel.tone(kind: .lumberjackHut, count: 18) == .neutral)
    #expect(AreaCountCapsuleModel.text(kind: .lumberjackHut, count: 3) == "3 trees in reach")
    #expect(AreaCountCapsuleModel.tone(kind: .lumberjackHut, count: 3) == .low)
    #expect(AreaCountCapsuleModel.text(kind: .lumberjackHut, count: 1) == "1 tree in reach")
    #expect(AreaCountCapsuleModel.text(kind: .lumberjackHut, count: 0) == "No trees in reach")
    #expect(AreaCountCapsuleModel.tone(kind: .lumberjackHut, count: 0) == .none)
    #expect(AreaCountCapsuleModel.text(kind: .forester, count: 12) == "12 open grass in reach")
    #expect(AreaCountCapsuleModel.tone(kind: .forester, count: 4) == .low)
}

@Test("scenario: mine site count")
func mineCapsuleText() {
    #expect(AreaCountCapsuleModel.text(kind: .mine, count: 4) == "Mine site: 4 rock tiles")
    #expect(AreaCountCapsuleModel.tone(kind: .mine, count: 2) == .neutral)
    #expect(AreaCountCapsuleModel.text(kind: .house, count: 4) == nil)
}

@Test("scenario: Apple TV type size")
func capsuleSizePerDevice() {
    #expect(AreaCountCapsuleLayout.metrics(for: .tv).fontSize == 24)
    #expect(AreaCountCapsuleLayout.metrics(for: .mac).fontSize == 12)
    #expect(AreaCountCapsuleLayout.metrics(for: .phone).fontSize == 13)
}

@Test("the capsule sits over the middle of the plot, above the roof")
func capsuleSitsAboveThePlot() {
    let camera = Camera(centerX: 10, centerY: 10, zoom: 1)
    let view = CGSize(width: 800, height: 600)
    let point = AreaCountCapsuleLayout.point(above: .lumberjackHut, at: TileCoordinate(x: 10, y: 10), camera: camera, viewSize: view)
    // The 2 by 2 plot's middle lies half a tile below (10, 10)'s centre; its top corner 32 points above that.
    let middle = PlacementHUDLayout.viewPoint(forTile: TileCoordinate(x: 10, y: 10), camera: camera, viewSize: view)
    #expect(point.x == middle.x)
    #expect(point.y == middle.y + 16 - 32 - AreaCountCapsuleLayout.roofLift - AreaCountCapsuleLayout.gap)
}

@Test("on touch the capsule clears the nudge arrows at any zoom")
func capsuleClearsTheNudgeArrows() {
    let view = CGSize(width: 844, height: 390)
    let anchor = TileCoordinate(x: 10, y: 10)
    for zoom in [0.5, 1.0, 2.0] {
        let camera = Camera(centerX: 10, centerY: 10, zoom: zoom)
        let point = AreaCountCapsuleLayout.point(above: .lumberjackHut, at: anchor, camera: camera, viewSize: view, clearsNudgeArrows: true)
        let center = PlacementHUDLayout.viewPoint(forTile: anchor, camera: camera, viewSize: view)
        for direction in NudgeDirection.allCases {
            let arrowTop = center.y + PlacementHUDLayout.arrowOffset(for: direction).height - PlacementHUDLayout.buttonSize / 2
            #expect(point.y <= arrowTop - AreaCountCapsuleLayout.gap)
        }
    }
}

@MainActor
@Test("an invalid ghost shows no area, even in a blight")
func invalidGhostHidesTheThreat() throws {
    let session = GameSession()
    session.world.seasonalEvents.warned = SeasonalEventOnset(event: .blight, season: .summer)
    session.world.seasonalEvents.marked = MarkedArea(around: TileBoundingBox(minX: 4, minY: 4, maxX: 5, maxY: 5), radius: 6)
    let threatened = session.areaOfEffect()
    let center = try #require(session.world.buildings.values.first { $0.kind == .townCenter })
    session.selectTool(.place(.lumberjackHut))
    session.handleHover(at: center.anchor)
    #expect(threatened?.style == .threat)
    #expect(session.areaOfEffect() == nil)
}

@MainActor
@Test("a plain building selected in a blight still shows the marked area")
func plainSelectionShowsTheThreat() throws {
    let session = GameSession()
    session.world.seasonalEvents.warned = SeasonalEventOnset(event: .blight, season: .summer)
    session.world.seasonalEvents.marked = MarkedArea(around: TileBoundingBox(minX: 4, minY: 4, maxX: 5, maxY: 5), radius: 6)
    let center = try #require(session.world.buildings.values.first { $0.kind == .townCenter })
    session.selectedTile = center.anchor
    let area = session.areaOfEffect()
    #expect(area?.style == .threat)
}
