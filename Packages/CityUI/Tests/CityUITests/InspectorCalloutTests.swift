import CoreGraphics
import Foundation
import Testing
@testable import CityCore
@testable import CityUI

// Scenarios from openspec/changes/redesign-hud-map-first/specs/platform-shells/spec.md.

private func inspector(
    for kind: BuildingKind, residents: UInt32? = nil, tier: HouseTier = .peasants
) throws -> InspectorViewModel {
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
        pop.tier = tier
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

@Test("scenario: callout names the next tier's needs")
func scenarioCalloutNamesTheNextTiersNeeds() throws {
    let citizens = try inspector(for: .house, residents: 6, tier: .citizens)
    // A Northern European town: its merchants' luxury is beer.
    #expect(citizens.keyLines.contains("Next: Merchants need bread, tools, cloth, beer"))
    let peasants = try inspector(for: .house, residents: 2)
    #expect(peasants.keyLines.contains("Next: Citizens need planks"))
    let merchants = try inspector(for: .house, residents: 8, tier: .merchants)
    #expect(!merchants.keyLines.contains { $0.hasPrefix("Next:") })
}

@Test("the next-tier line uses the town's tier names and luxury")
func nextTierLineFollowsTheCulture() {
    #expect(InspectorViewModel.nextTierLine(after: .citizens, in: .mediterranean)
        == ["Next: Patricians need bread, tools, cloth, wine"])
    #expect(InspectorViewModel.nextTierLine(after: .peasants, in: .mediterranean) == ["Next: Citizens need planks"])
}

@Test("scenario: callout key lines for other buildings")
func scenarioCalloutKeyLinesForOtherBuildings() throws {
    let inspector = try inspector(for: .lumberjackHut)
    #expect(inspector.keyLines.count == 4)
    #expect(inspector.keyLines.first?.hasPrefix("State:") == true)
    #expect(inspector.keyLines.dropFirst().first?.hasPrefix("Road:") == true)
    #expect(inspector.tier == nil)
    #expect(inspector.residentsFill == nil)
}

@Test("scenario: callout names what stops a building")
func scenarioCalloutNamesWhatStopsABuilding() throws {
    let inspector = try inspector(for: .farm)
    #expect(inspector.problem == "No road: connect it to a road")
    #expect(inspector.keyLines.last == "Problem: No road: connect it to a road")
}

@Test("scenario: problem text for every building issue")
func scenarioProblemTextForEveryBuildingIssue() {
    #expect(InspectorViewModel.problemText(.noRouteToStorage) == "Its road doesn't reach a warehouse or the town center")
    #expect(InspectorViewModel.problemText(.noTreesInReach) == "No forest within 2 tiles: build a forester beside it")
    #expect(InspectorViewModel.problemText(.noRoomToPlant) == "No open grass within 2 tiles to plant")
    #expect(InspectorViewModel.problemText(.missingInputs([.wood, .grain])) == "Waiting for wood, grain")
    #expect(InspectorViewModel.problemText(.outputStuck(.bread)) == "Output stuck: no room for bread")
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
