import CityCore
import Foundation
import Testing
@testable import CityUI

// Scenarios from openspec/changes/decline-grace: platform-shells / The
// inspector warns of a house about to decline.

private func merchantHouse(issue: BuildingIssue) throws -> InspectorViewModel {
    var world = World.fixtureWithTerrain(width: 8, height: 8, fill: .grass, seed: 1)
    let anchor = TileCoordinate(x: 2, y: 2)
    world.enqueue(.place(.house, at: anchor))
    for _ in 0 ..< 30 {
        world.tick()
    }
    let house = try #require(world.occupiedTiles[anchor])
    var pop = HousePopulation()
    pop.tier = .merchants
    pop.population = 8
    let snapshot = withBuildingIssues(withHousePopulations(world.snapshot(), [house: pop]), [house: issue])
    return InspectorViewModel.make(from: snapshot, tile: anchor, buildings: snapshot.buildings)
}

@Test("scenario: problem text names the coming decline")
func scenarioProblemTextNamesTheComingDecline() {
    #expect(InspectorViewModel.problemText(.runningShort(.tools, intervals: 1, grace: 3)) == "Short of tools: residents will leave")
    #expect(InspectorViewModel.problemText(.runningShort(.tools, intervals: 3, grace: 3)) == "Short of tools: residents are leaving")
    #expect(InspectorViewModel.problemText(.runningShort(.tools, intervals: 2, grace: 3)) == "Short of tools: residents will leave")
}

@Test("scenario: details counts the intervals")
func scenarioDetailsCountsTheIntervals() throws {
    let inspector = try merchantHouse(issue: .runningShort(.tools, intervals: 2, grace: 3))
    #expect(inspector.bullets.contains("Short of tools: 2 of 3 intervals"))
    #expect(inspector.keyLines.last == "Problem: Short of tools: residents will leave")
    #expect(inspector.problem == "Short of tools: residents will leave")
}

@Test func otherIssuesAddNoShortageLine() throws {
    let inspector = try merchantHouse(issue: .noRoad)
    #expect(!inspector.bullets.contains { $0.hasPrefix("Short of") })
}
