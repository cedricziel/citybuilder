import CityCore
import Foundation
import Testing
@testable import CityUI

// Scenarios from openspec/changes/add-forestry/specs/platform-shells/spec.md.

/// The inspector for a `kind` built on a grass fixture, with its
/// snapshot count of trees or open grass in reach set to `inReach`.
private func inspector(for kind: BuildingKind, inReach: Int) throws -> InspectorViewModel {
    var world = World.fixtureWithTerrain(width: 8, height: 8, fill: .grass, seed: 1)
    let anchor = TileCoordinate(x: 2, y: 2)
    world.enqueue(.place(kind, at: anchor))
    for _ in 0 ..< 30 {
        world.tick()
    }
    let id = try #require(world.occupiedTiles[anchor])
    let snapshot = withCatchments(world.snapshot(), [id: inReach])
    return InspectorViewModel.make(from: snapshot, tile: anchor, buildings: snapshot.buildings)
}

/// The first anchor on the new-game map where an unbuilt `kind` would
/// reach exactly `count` tiles.
private func anchor(for kind: BuildingKind, reaching count: Int, in world: World) throws -> TileCoordinate {
    let tiles = (0 ..< world.mapHeight).lazy.flatMap { y in (0 ..< world.mapWidth).lazy.map { TileCoordinate(x: $0, y: y) } }
    return try #require(tiles.first { world.catchmentCount(kind: kind, anchor: $0, owner: .player) == count })
}

@Test("scenario: hut key lines show trees in reach")
func scenarioHutKeyLinesShowTreesInReach() throws {
    let inspector = try inspector(for: .lumberjackHut, inReach: 7)
    #expect(inspector.keyLines.count >= 3)
    #expect(inspector.keyLines.first?.hasPrefix("State:") == true)
    #expect(inspector.keyLines.dropFirst().first?.hasPrefix("Road:") == true)
    #expect(inspector.keyLines.dropFirst(2).first == "Trees in reach: 7")
}

@Test("scenario: forester key lines show open grass")
func scenarioForesterKeyLinesShowOpenGrass() throws {
    let inspector = try inspector(for: .forester, inReach: 12)
    #expect(inspector.keyLines.contains("Open grass in reach: 12"))
    #expect(!inspector.keyLines.contains { $0.hasPrefix("Trees in reach:") })
}

@Test("other buildings show nothing in reach")
func otherBuildingsShowNothingInReach() throws {
    let inspector = try inspector(for: .farm, inReach: 5)
    #expect(!inspector.bullets.contains { $0.contains("in reach") })
}

@MainActor
@Test("scenario: tool strip hint shows trees at the candidate site")
func scenarioToolStripHintShowsTreesAtTheCandidateSite() throws {
    let session = GameSession()
    session.selectTool(.place(.lumberjackHut))
    try session.handleHover(at: anchor(for: .lumberjackHut, reaching: 9, in: session.world))
    #expect(session.armedInReachCount == 9)
    let hint = ToolStripText.hint(for: session.selectedTool, idiom: .phone, inReach: session.armedInReachCount)
    #expect(hint == "Tap or drag to place lumberjack · 9 trees in reach")
}

@MainActor
@Test("scenario: tool strip hint without a candidate site")
func scenarioToolStripHintWithoutACandidateSite() {
    let session = GameSession()
    session.selectTool(.place(.forester))
    #expect(session.armedInReachCount == nil)
    let hint = ToolStripText.hint(for: session.selectedTool, idiom: .mac, inReach: session.armedInReachCount)
    #expect(hint == "Click or drag to place forester")
}

@Test("forester tool strip hint counts open grass")
func foresterToolStripHintCountsOpenGrass() {
    #expect(ToolStripText.hint(for: .place(.forester), idiom: .mac, inReach: 12)
        == "Click or drag to place forester · 12 open grass in reach")
    #expect(ToolStripText.hint(for: .place(.house), idiom: .mac, inReach: 12) == "Click or drag to place house")
}

@MainActor
@Test("a pending placement is the candidate site")
func aPendingPlacementIsTheCandidateSite() throws {
    let session = GameSession()
    let site = try anchor(for: .lumberjackHut, reaching: 9, in: session.world)
    session.selectTool(.place(.lumberjackHut))
    session.pendingPlacement = PendingPlacement(kind: .lumberjackHut, anchor: site, origin: site)
    #expect(session.armedInReachCount == 9)
}

@Test("the forester sits in the gather drawer after the lumberjack hut")
func theForesterSitsInTheGatherDrawerAfterTheLumberjackHut() {
    let gather = BuildCategory.kinds(in: .gather, isHidden: { _ in false })
    let hut = gather.firstIndex(of: .lumberjackHut)
    #expect(hut.map { gather.index(after: $0) }.map { gather[$0] } == .forester)
    #expect(BuildTool.place(.forester).displayName == "Forester")
}
