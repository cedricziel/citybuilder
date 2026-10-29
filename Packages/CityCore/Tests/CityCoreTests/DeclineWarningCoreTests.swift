import Foundation
import Testing
@testable import CityCore

// Scenarios from openspec/changes/decline-grace: rendering-2_5d / A house
// running short shows the short icon before it declines.

private func warningHouse() throws -> HouseFixture {
    var fixture = try merchantHouse()
    restock(&fixture, missing: [])
    return fixture
}

private func record(_ fixture: inout HouseFixture, _ good: Good, intervals: Int) {
    for _ in 0 ..< intervals {
        fixture.world.populations[fixture.house]?.recordConsumption(of: good, short: true)
    }
}

@Test("scenario: a house in its grace reports the need nearest to decline")
func scenarioAHouseInItsGraceReportsTheNeedNearestToDecline() throws {
    var fixture = try warningHouse()
    try #require(grace(fixture) >= 3)
    record(&fixture, .bread, intervals: 1)
    record(&fixture, .tools, intervals: 2)
    let issue = fixture.world.buildingIssues()[fixture.house]
    #expect(issue == .runningShort(.tools, intervals: 2, grace: grace(fixture)))
    #expect(issue?.isDeclining == false)
}

@Test("scenario: a tie goes to the first need of the tier")
func scenarioATieGoesToTheFirstNeedOfTheTier() throws {
    var fixture = try warningHouse()
    record(&fixture, .tools, intervals: 1)
    record(&fixture, .bread, intervals: 1)
    #expect(fixture.world.buildingIssues()[fixture.house] == .runningShort(.bread, intervals: 1, grace: grace(fixture)))
}

@Test("scenario: a house past its grace says it is declining")
func scenarioAHousePastItsGraceSaysItIsDeclining() throws {
    var fixture = try warningHouse()
    record(&fixture, .tools, intervals: grace(fixture))
    let issue = fixture.world.buildingIssues()[fixture.house]
    #expect(issue == .runningShort(.tools, intervals: grace(fixture), grace: grace(fixture)))
    #expect(issue?.isDeclining == true)
}

@Test("scenario: a road problem comes before a shortage")
func scenarioARoadProblemComesBeforeAShortage() throws {
    var world = World.fixtureWithTerrain(width: 6, height: 6, fill: .grass, seed: 1)
    world.enqueue(.place(.house, at: TileCoordinate(x: 1, y: 1)))
    for _ in 0 ..< 30 {
        world.tick()
    }
    let house = try #require(world.occupiedTiles[TileCoordinate(x: 1, y: 1)])
    var population = HousePopulation()
    population.tier = .merchants
    population.population = 8
    population.recordConsumption(of: .tools, short: true)
    world.populations[house] = population
    #expect(world.buildingIssues()[house] == .noRoad)
}

@Test("scenario: a need that does not bind raises no warning")
func scenarioANeedThatDoesNotBindRaisesNoWarning() throws {
    var fixture = try warningHouse()
    fixture.world.research = ResearchState(researched: Tech.allCases.filter { $0 != .weaving })
    record(&fixture, .cloth, intervals: 2)
    #expect(fixture.world.buildingIssues()[fixture.house] == nil)
}

@Test("scenario: an empty house raises no warning")
func scenarioAnEmptyHouseRaisesNoWarning() throws {
    var fixture = try warningHouse()
    record(&fixture, .tools, intervals: 1)
    fixture.world.populations[fixture.house]?.population = 0
    #expect(fixture.world.buildingIssues()[fixture.house] == nil)
}
