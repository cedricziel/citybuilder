import Foundation
import Testing
@testable import CityCore

// Scenarios from openspec/changes/add-city-life.

@Test("scenario: midday is bright")
func scenarioMiddayIsBright() {
    let time = TimeOfDay(tick: 600)
    #expect(time.phase == .day)
    #expect(time.darkness == 0)
}

@Test("scenario: midnight is dark")
func scenarioMidnightIsDark() {
    let time = TimeOfDay(tick: 1200)
    #expect(time.phase == .night)
    #expect(time.darkness == 0.55)
    #expect(TimeOfDay(tick: 300).phase == .dawn)
    #expect(TimeOfDay(tick: 960).phase == .dusk)
    #expect(abs(TimeOfDay(tick: 300).darkness - 0.275) < 1e-9)
}

@Test("scenario: names are stable")
func scenarioNamesAreStable() throws {
    let world = World.newGame(layout: .singleIsland, seed: 0, culture: .eastAsian)
    let house = EntityID(raw: 42)
    let names = world.residentNames(for: house, count: 3)
    #expect(names.count == 3)
    #expect(Set(names).count == 3)
    let data = try JSONEncoder().encode(world)
    let reloaded = try JSONDecoder().decode(World.self, from: data)
    #expect(reloaded.residentNames(for: house, count: 3) == names)
    #expect(names.allSatisfy { ResidentNames.list(for: .eastAsian).contains($0) })
}
