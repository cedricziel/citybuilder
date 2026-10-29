@testable import CityCore

extension Chapter {
    /// A placeholder chapter for tests: not real campaign content.
    static func testChapter(
        layout: WorldLayout = .singleIsland,
        seed: UInt64 = 5,
        age: Age = .medieval,
        culture: Culture? = nil,
        rivals: Int = 0,
        start: ChapterStart = ChapterStart(money: 1000, stock: [.wood: 6, .planks: 5, .food: 2]),
        overrides: [Difficulty: ChapterStartOverride] = [:],
        directives: [TerrainDirective] = [],
        closedBuildings: Set<BuildingKind> = [],
        closedTechs: Set<Tech> = [],
        researched: [Tech] = [],
        goals: [GoalState] = [GoalState(goal: .population(40, atLeast: .peasants))],
        loseConditions: [LoseCondition] = [],
        rivalAgeYears: [Age: Int] = [:],
        events: [ScheduledSeasonalEvent] = [],
        randomEvents: Bool = true
    ) -> Chapter {
        Chapter(
            id: "test-chapter", title: "Test Chapter", intro: "A test.", ending: "Done.",
            layout: layout, seed: seed, age: age, culture: culture, rivals: rivals, start: start, overrides: overrides,
            directives: directives, closedBuildings: closedBuildings, closedTechs: closedTechs, researched: researched,
            goals: goals, loseConditions: loseConditions, rivalAgeYears: rivalAgeYears,
            reward: .banner("Test"), events: events, randomEvents: randomEvents
        )
    }
}
