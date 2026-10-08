import CityCore
import Foundation
import Testing
@testable import CityUI

@Test("scenario: inspector reports road access")
func scenarioInspectorReportsRoadAccess() {
    var world = World.fixtureWithTerrain(width: 8, height: 8, fill: .grass, seed: 1)
    let anchor = TileCoordinate(x: 2, y: 2)
    world.enqueue(.place(.house, at: anchor))
    world.tick()
    let snapshot = world.snapshot()
    let lines = InspectorViewModel.make(from: snapshot, tile: anchor, buildings: snapshot.buildings).bullets
    #expect(lines.contains("Road: none"))

    world.enqueue(.place(.road, at: TileCoordinate(x: 1, y: 2)))
    world.tick()
    let connected = world.snapshot()
    #expect(InspectorViewModel.make(from: connected, tile: anchor, buildings: connected.buildings).bullets
        .contains("Road: connected"))
}
