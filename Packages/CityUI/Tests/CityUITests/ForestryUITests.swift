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
