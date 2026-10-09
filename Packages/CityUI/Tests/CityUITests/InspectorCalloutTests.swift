import CityCore
import CoreGraphics
import Foundation
import Testing
@testable import CityUI

// Scenarios from openspec/changes/redesign-hud-map-first/specs/platform-shells/spec.md.

private func inspector(for kind: BuildingKind, residents: UInt32? = nil) throws -> InspectorViewModel {
    var world = World.fixtureWithTerrain(width: 8, height: 8, fill: .grass, seed: 1)
    let anchor = TileCoordinate(x: 2, y: 2)
    world.enqueue(.place(kind, at: anchor))
    for _ in 0 ..< 30 {
        world.tick()
    }
    var snapshot = world.snapshot()
    if let residents {
        let id = try #require(world.occupiedTiles[anchor])
        var pop = HousePopulation()
        pop.population = residents
        snapshot = withHousePopulations(snapshot, [id: pop])
    }
    return InspectorViewModel.make(from: snapshot, tile: anchor, buildings: snapshot.buildings)
}

@Test("scenario: callout title and key lines")
func scenarioCalloutTitleAndKeyLines() throws {
    let inspector = try inspector(for: .house, residents: 2)
    #expect(inspector.title == "House")
    #expect(inspector.tier == "Peasants")
    let fill = try #require(inspector.residentsFill)
    #expect(abs(fill - 0.5) < 0.0001)
    #expect(inspector.keyLines.first == "Residents: 2/4")
    #expect(inspector.keyLines.dropFirst().first?.hasPrefix("Needs:") == true)
}

@Test("scenario: callout key lines for other buildings")
func scenarioCalloutKeyLinesForOtherBuildings() throws {
    let inspector = try inspector(for: .lumberjackHut)
    #expect(inspector.keyLines.count == 2)
    #expect(inspector.keyLines.first?.hasPrefix("State:") == true)
    #expect(inspector.keyLines.last?.hasPrefix("Road:") == true)
    #expect(inspector.tier == nil)
    #expect(inspector.residentsFill == nil)
}

private let viewBounds = CGRect(x: 0, y: 0, width: 844, height: 390)
private let calloutSize = CGSize(width: 220, height: 120)

@Test("scenario: callout flips at the edge")
func scenarioCalloutFlipsAtTheEdge() {
    let placed = InspectorCalloutLayout.place(
        anchor: CGPoint(x: 830, y: 200),
        buildingHalfSize: CGSize(width: 20, height: 10),
        calloutSize: calloutSize,
        bounds: viewBounds,
        placement: .leftRail
    )
    #expect(placed.side == .leading)
    let rightEdge: CGFloat = placed.origin.x + calloutSize.width
    #expect(rightEdge <= 830 - 20)
}

@Test("scenario: callout stays on screen")
func scenarioCalloutStaysOnScreen() {
    let free = CGRect(x: 72, y: 66, width: 760, height: 300)
    let placed = InspectorCalloutLayout.place(
        anchor: CGPoint(x: 300, y: 70),
        buildingHalfSize: CGSize(width: 20, height: 10),
        calloutSize: calloutSize,
        bounds: free,
        placement: .leftRail
    )
    #expect(placed.side == .trailing)
    #expect(placed.origin.y == free.minY)
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
