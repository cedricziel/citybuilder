import Foundation
import Testing
@testable import CityCore

// rival-towns / Rival viability (change rival-ai-viability, M3).

/// Seed 0 is checked by default, one game per difficulty run in parallel;
/// `RIVAL_SWEEP=1` widens it to seeds 0–9 for
/// release runs (design D7).
private let sweepSeeds: [UInt64] = ProcessInfo.processInfo.environment["RIVAL_SWEEP"] == "1"
    ? Array(0 ..< 10) : [0]

struct ViabilityCase: CustomTestStringConvertible, Sendable {
    let seed: UInt64
    let difficulty: Difficulty

    var testDescription: String {
        "seed \(seed), \(difficulty.rawValue)"
    }
}

private let viabilityCases = sweepSeeds.flatMap { seed in
    Difficulty.allCases.map { ViabilityCase(seed: seed, difficulty: $0) }
}

/// Residents every rival has by the end of year 5.
private func residentsFloor(_ difficulty: Difficulty) -> Int {
    switch difficulty {
    case .easy: 8
    case .normal: 20
    case .hard: 30
    }
}

@Test("scenario: rivals are viable across seeds", arguments: viabilityCases)
func scenarioRivalsAreViableAcrossSeeds(_ viability: ViabilityCase) {
    var world = World.newGame(layout: .archipelago, seed: viability.seed, difficulty: viability.difficulty)
    let year = Int(CalendarState.ticksPerYear)
    var ticksInDebt: [RivalID: Int] = [:]
    for tick in 1 ... 5 * year {
        // A passive player kept solvent: game over would stop rival tax and upkeep.
        if tick.isMultiple(of: 600) { world.economy.balance = 100_000 }
        world.tick()
        for rival in world.rivals {
            ticksInDebt[rival.id] = rival.treasury < 0 ? ticksInDebt[rival.id, default: 0] + 1 : 0
            #expect(ticksInDebt[rival.id, default: 0] < year, "rival \(rival.id) in debt for a year")
        }
        if tick >= 2 * year, tick.isMultiple(of: year) {
            for rival in world.rivals {
                #expect(world.population(of: rival.owner) > 0, "rival \(rival.id) empty at tick \(tick)")
            }
        }
    }
    for rival in world.rivals {
        let residents = world.population(of: rival.owner)
        #expect(residents >= residentsFloor(viability.difficulty), "rival \(rival.id) has \(residents)")
    }
}
