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

/// The control: without the market these seeds go bankrupt by tick
/// 4,000, so the sweep above tests what the market does. Direct hops
/// (visible-distribution milestone 1) kept seeds 2, 6 and 21 solvent
/// without it, so they gave way to 1, 3 and 11.
@Test(
    "scenario: without the market the same towns go bankrupt",
    .enabled(if: isFullSweep, "set RIVAL_SWEEP=1"),
    arguments: [UInt64(1), 3, 9, 11]
)
func scenarioWithoutTheMarketTheSameTownsGoBankrupt(seed: UInt64) {
    let bankrupt = World.botGame(
        layout: .archipelago, seed: seed, difficulty: .normal, tradesAtMarket: false, ticks: 4000
    ).economy.gameOver
    print("SOLVENCY_SWEEP seed=\(seed) layout=archipelago market=false bankrupt=\(bankrupt)")
    #expect(bankrupt, "archipelago seed \(seed)")
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
