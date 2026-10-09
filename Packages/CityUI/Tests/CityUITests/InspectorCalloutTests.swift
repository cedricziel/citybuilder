import CityCore
import CoreGraphics
import Foundation
import Testing
@testable import CityUI

// Scenarios from openspec/changes/redesign-hud-map-first/specs/platform-shells/spec.md.

@Test("scenario: callout title and key lines")
func scenarioCalloutTitleAndKeyLines() throws {
    var world = World.fixtureWithTerrain(width: 8, height: 8, fill: .grass, seed: 1)
    let anchor = TileCoordinate(x: 2, y: 2)
    world.enqueue(.place(.house, at: anchor))
    for _ in 0 ..< 30 {
        world.tick()
    }
    let house = try #require(world.occupiedTiles[anchor])
    var pop = HousePopulation()
    pop.population = 2
    let snapshot = withHousePopulations(world.snapshot(), [house: pop])
    let inspector = InspectorViewModel.make(from: snapshot, tile: anchor, buildings: snapshot.buildings)
    #expect(inspector.title == "House")
    let lines = inspector.keyLines
    #expect(lines.first?.hasPrefix("State:") == true)
    #expect(lines.contains { $0.hasPrefix("Road:") })
    #expect(lines.contains { $0.hasPrefix("Residents:") })
}

@Test("scenario: callout stays on screen")
func scenarioCalloutStaysOnScreen() {
    let origin = InspectorCalloutLayout.origin(
        anchor: CGPoint(x: 830, y: 200),
        calloutSize: CGSize(width: 220, height: 120),
        viewSize: CGSize(width: 844, height: 390),
        placement: .leftRail
    )
    let rightEdge: CGFloat = origin.x + 220
    #expect(rightEdge == 836)
    #expect(origin.y >= 8)
}

@MainActor
@Test("scenario: demolish from the callout")
func scenarioDemolishFromTheCallout() {
    let world = World.fixtureWithTerrain(width: 8, height: 8, fill: .grass, seed: 1)
    let session = GameSession(world: world)
    let anchor = TileCoordinate(x: 2, y: 2)
    session.world.enqueue(.place(.house, at: anchor))
    session.world.tick()
    session.handleTap(at: anchor)
    session.demolishSelection()
    #expect(session.world.pendingCommands == [.demolish(at: anchor)])
    #expect(session.selectedTile == nil)
}
