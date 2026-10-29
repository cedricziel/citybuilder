import Foundation
@testable import CityCore

/// A grass world in spring 1200 with an active calendar and seasonal
/// events on.
func eventsWorld(seed: UInt64 = 1, difficulty: Difficulty = .normal, age: Age = .medieval, size: Int = 32) -> World {
    var world = World.fixtureWithTerrain(width: size, height: size, fill: .grass, seed: seed)
    world.calendar = CalendarState(startYear: 1200, isActive: true)
    world.difficulty = difficulty
    world.age = age
    world.seasonalEvents.enabled = true
    return world
}

/// Puts an operational player building at `anchor` without construction;
/// a house gets `residents`.
@discardableResult
func addOperational(_ kind: BuildingKind, at anchor: TileCoordinate, residents: UInt32 = 0, in world: inout World) -> EntityID {
    let id = SignatureFixture.inject(kind, at: anchor, in: &world)
    if kind == .house {
        var population = HousePopulation()
        population.population = residents
        world.populations[id] = population
    }
    return id
}

/// `count` houses with residents in a row of 2×2 plots, three tiles apart
/// so no two touch.
func addHouses(_ count: Int, residents: UInt32 = 4, row: Int = 0, in world: inout World) {
    for index in 0 ..< count {
        addOperational(.house, at: TileCoordinate(x: index * 3, y: row), residents: residents, in: &world)
    }
}

/// Ticks until `tick` and returns every event on the way.
func runEvents(_ world: inout World, untilTick tick: UInt64) -> [WorldEvent] {
    var events: [WorldEvent] = []
    while world.tickCount < tick {
        events += world.tick().events
    }
    return events
}

/// Runs to `tick` like `runEvents`, but jumps the clock over the ticks
/// between season changes, which seasonal events don't act on: only the
/// last tick of each season and the first of the next run. Nothing else
/// in the world advances meanwhile.
func runSeasons(_ world: inout World, untilTick tick: UInt64) -> [WorldEvent] {
    var events: [WorldEvent] = []
    while world.tickCount < tick {
        let target = min((world.tickCount / CalendarState.ticksPerSeason + 1) * CalendarState.ticksPerSeason, tick)
        if target > world.tickCount + 2 {
            world.tickCount = target - 2
            world.simulatedTime = .milliseconds(Int64(target - 2) * 100)
        }
        events += runEvents(&world, untilTick: target)
    }
    return events
}

/// The first tick of `season` in `year` for a calendar starting in 1200.
func firstTick(of season: Season, _ year: Int) -> UInt64 {
    UInt64(year - 1200) * CalendarState.ticksPerYear + UInt64(season.rawValue) * CalendarState.ticksPerSeason
}

/// The first seed whose draw for `year` is `onset`. The draw ignores the
/// map and the buildings, so the search runs on one-tile worlds.
func seedDrawing(
    _ onset: SeasonalEventOnset, in year: Int, difficulty: Difficulty = .normal, age: Age = .medieval
) -> UInt64? {
    (0 ..< 2000).first { eventsWorld(seed: $0, difficulty: difficulty, age: age, size: 1).seasonalEvent(forYear: year) == onset }
}

/// A seed whose 1202 draw on Normal is a fire in summer.
let summerFireSeed = seedDrawing(SeasonalEventOnset(event: .fire, season: .summer), in: 1202)

extension [WorldEvent] {
    var seasonalEvents: [WorldEvent] {
        filter {
            switch $0 {
            case .seasonalEventWarned, .seasonalEventStarted, .seasonalEventEnded: true
            default: false
            }
        }
    }
}
