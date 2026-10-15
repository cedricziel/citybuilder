import Foundation
import Testing
@testable import CityCore

// rival-towns / Rival viability (change rival-ai-viability, M3, design D7).
//
// The full sweep runs seeds 0–9 at every difficulty over 36,000 ticks
// (15 years) and checks the year-5 floors. It takes minutes even in a
// release build, so it runs only with `RIVAL_SWEEP=1`: in the weekly
// `rival-sweep` workflow, and by hand at a milestone's end. Every CI run
// checks seed 0 over 3 years instead.

struct ViabilityCase: CustomTestStringConvertible, Sendable {
    let seed: UInt64
    let difficulty: Difficulty

    var testDescription: String {
        "seed \(seed), \(difficulty.rawValue)"
    }
}

private let isFullSweep = ProcessInfo.processInfo.environment["RIVAL_SWEEP"] == "1"

private func cases(seeds: [UInt64]) -> [ViabilityCase] {
    seeds.flatMap { seed in Difficulty.allCases.map { ViabilityCase(seed: seed, difficulty: $0) } }
}

/// Residents every rival has by the end of year 5.
private func residentsFloor(_ difficulty: Difficulty) -> Int {
    switch difficulty {
    case .easy: 8
    case .normal: 20
    case .hard: 30
    }
}

/// What one game's rivals did, per rival.
private struct ViabilityRun {
    var residentsAtYearEnd: [RivalID: [Int]] = [:]
    var emptySince: [RivalID: Int] = [:]
    var longestDebt: [RivalID: Int] = [:]
    var lowestTreasury: [RivalID: Int64] = [:]
}

/// Runs `years` years with a passive player kept solvent (a game over
/// would stop rival tax and upkeep) and records the viability measures.
private func runRivals(_ viability: ViabilityCase, years: Int) -> ViabilityRun {
    var world = World.newGame(layout: .archipelago, seed: viability.seed, difficulty: viability.difficulty)
    let year = Int(CalendarState.ticksPerYear)
    var run = ViabilityRun()
    var debt: [RivalID: Int] = [:]
    for tick in 1 ... years * year {
        if tick.isMultiple(of: 600) { world.economy.balance = 100_000 }
        world.tick()
        for rival in world.rivals {
            debt[rival.id] = rival.treasury < 0 ? debt[rival.id, default: 0] + 1 : 0
            run.longestDebt[rival.id] = max(run.longestDebt[rival.id, default: 0], debt[rival.id, default: 0])
            run.lowestTreasury[rival.id] = min(run.lowestTreasury[rival.id] ?? .max, rival.treasury)
            let residents = world.population(of: rival.owner)
            // After the end of year 2 no rival may empty, not even for a tick.
            if tick >= 2 * year, residents == 0, run.emptySince[rival.id] == nil {
                run.emptySince[rival.id] = tick
            }
            if tick.isMultiple(of: year) {
                run.residentsAtYearEnd[rival.id, default: []].append(residents)
            }
        }
    }
    return run
}

private func expectViable(_ run: ViabilityRun) {
    let year = Int(CalendarState.ticksPerYear)
    #expect(run.emptySince.isEmpty, "rivals empty after year 2, from tick: \(run.emptySince)")
    for (rival, longest) in run.longestDebt {
        #expect(longest < year, "rival \(rival) in debt for \(longest) ticks")
    }
}

@Test("rivals stay viable through year 3", arguments: cases(seeds: [0]))
func rivalsStayViableThroughYear3(_ viability: ViabilityCase) {
    expectViable(runRivals(viability, years: 3))
}

@Test(
    "scenario: rivals are viable across seeds",
    .enabled(if: isFullSweep, "set RIVAL_SWEEP=1"),
    arguments: cases(seeds: Array(0 ..< 10))
)
func scenarioRivalsAreViableAcrossSeeds(_ viability: ViabilityCase) {
    let run = runRivals(viability, years: 15)
    expectViable(run)
    for (rival, residents) in run.residentsAtYearEnd.sorted(by: { $0.key < $1.key }) {
        #expect(residents[4] >= residentsFloor(viability.difficulty), "rival \(rival) has \(residents[4]) at year 5")
        // The sweep's evidence for design "M3 result", one line per rival.
        print(
            "RIVAL_SWEEP seed=\(viability.seed) difficulty=\(viability.difficulty.rawValue) rival=\(rival)",
            "year3=\(residents[2]) year5=\(residents[4]) year15=\(residents[14])",
            "lowestTreasury=\(run.lowestTreasury[rival] ?? 0)"
        )
    }
}
