import Foundation
import Testing
@testable import CityCore

// economy / Early solvency with the market (openspec/changes/hard-bankruptcy-grace).
// A bot game of a few thousand ticks takes about 2 minutes in a debug
// build, so both checks run only when asked, as the weekly `rival-sweep`
// workflow does (design D2).

private let isFullSweep = ProcessInfo.processInfo.environment["RIVAL_SWEEP"] == "1"

@Test(
    "scenario: market-trading towns stay solvent across seeds",
    .enabled(if: isFullSweep, "set RIVAL_SWEEP=1"),
    arguments: Array(UInt64(0) ..< 10)
)
func scenarioMarketTradingTownsStaySolventAcrossSeeds(seed: UInt64) {
    for layout in [WorldLayout.singleIsland, .archipelago] {
        let bankrupt = World.botGame(
            layout: layout, seed: seed, difficulty: .normal, tradesAtMarket: true, ticks: 36000
        ).economy.gameOver
        print("SOLVENCY_SWEEP seed=\(seed) layout=\(layout.rawValue) market=true bankrupt=\(bankrupt)")
        #expect(!bankrupt, "\(layout) seed \(seed)")
    }
}

/// The control: over archipelago seeds 0 to 29 on Normal, by tick 4,000,
/// towns that trade at the market go bankrupt no more often, and house at
/// least 95% as many residents in all, as the same towns without it. It
/// once asked for bankruptcies without the market; per-good storage ended
/// the store clog that caused them (`per-good-storage` D5), and with
/// handcarts market-less towns grow slightly faster (#268).
private let controlSeeds = Array(UInt64(0) ..< 30)

@Test(
    "scenario: the market does not make towns worse off",
    .enabled(if: isFullSweep, "set RIVAL_SWEEP=1")
)
func scenarioTheMarketDoesNotMakeTownsWorseOff() async {
    let without = await controlRuns(tradesAtMarket: false)
    let with = await controlRuns(tradesAtMarket: true)
    print(
        "SOLVENCY_SWEEP control seeds=0-29 layout=archipelago bankrupt_without=\(without.bankrupt) "
            + "bankrupt_with=\(with.bankrupt) residents_without=\(without.residents) residents_with=\(with.residents)"
    )
    #expect(with.bankrupt <= without.bankrupt)
    // Within 5%: a town without the market may out-grow one with it (#268).
    #expect(with.residents * 100 >= without.residents * 95)
}

/// Bankruptcies and residents in all over the control seeds.
private func controlRuns(tradesAtMarket: Bool) async -> (bankrupt: Int, residents: Int) {
    await withTaskGroup(of: (Bool, Int).self) { group in
        for seed in controlSeeds {
            group.addTask {
                let world = World.botGame(
                    layout: .archipelago, seed: seed, difficulty: .normal,
                    tradesAtMarket: tradesAtMarket, ticks: 4000
                )
                return (world.economy.gameOver, world.residents(atLeast: .peasants))
            }
        }
        return await group.reduce((bankrupt: 0, residents: 0)) { total, run in
            (total.bankrupt + (run.0 ? 1 : 0), total.residents + run.1)
        }
    }
}

// economy / Following the first steps keeps a Hard start solvent and
// growing (openspec/changes/first-hour-guidance, design D4).

@Test(
    "scenario: guided Hard start stays solvent and grows",
    .enabled(if: isFullSweep, "set RIVAL_SWEEP=1"),
    arguments: Array(UInt64(0) ..< 10)
)
func scenarioGuidedHardStartStaysSolventAndGrows(seed: UInt64) {
    for layout in [WorldLayout.singleIsland, .archipelago] {
        let world = World.botGame(
            layout: layout, seed: seed, difficulty: .hard, tradesAtMarket: true,
            firstSteps: PlayerBot.guideSteps, ticks: 12000
        )
        let residents = world.population(of: .player)
        print("GUIDE_SWEEP seed=\(seed) layout=\(layout.rawValue) bankrupt=\(world.economy.gameOver) residents=\(residents)")
        #expect(!world.economy.gameOver, "\(layout) seed \(seed)")
        #expect(residents >= 25, "\(layout) seed \(seed): \(residents) residents")
    }
}

/// The control: today every one of these starts goes bankrupt in year 2.
@Test(
    "scenario: unguided Hard start goes bankrupt",
    .enabled(if: isFullSweep, "set RIVAL_SWEEP=1"),
    arguments: [UInt64(0), 5]
)
func scenarioUnguidedHardStartGoesBankrupt(seed: UInt64) {
    for layout in [WorldLayout.singleIsland, .archipelago] {
        let world = World.botGame(layout: layout, seed: seed, difficulty: .hard, tradesAtMarket: false, ticks: 12000)
        print("GUIDE_SWEEP seed=\(seed) layout=\(layout.rawValue) unguided bankrupt=\(world.economy.gameOver)")
        #expect(world.economy.gameOver, "\(layout) seed \(seed)")
    }
}
