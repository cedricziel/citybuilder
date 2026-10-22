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
        let bankrupt = World.botGoesBankrupt(
            layout: layout, seed: seed, difficulty: .normal, tradesAtMarket: true, ticks: 36000
        )
        print("SOLVENCY_SWEEP seed=\(seed) layout=\(layout.rawValue) market=true bankrupt=\(bankrupt)")
        #expect(!bankrupt, "\(layout) seed \(seed)")
    }
}

/// The control: without the market these seeds go bankrupt by tick
/// 3,850, so the sweep above tests what the market does.
@Test(
    "scenario: without the market the same towns go bankrupt",
    .enabled(if: isFullSweep, "set RIVAL_SWEEP=1"),
    arguments: [UInt64(2), 6, 9, 21]
)
func scenarioWithoutTheMarketTheSameTownsGoBankrupt(seed: UInt64) {
    let bankrupt = World.botGoesBankrupt(
        layout: .archipelago, seed: seed, difficulty: .normal, tradesAtMarket: false, ticks: 4000
    )
    print("SOLVENCY_SWEEP seed=\(seed) layout=archipelago market=false bankrupt=\(bankrupt)")
    #expect(bankrupt, "archipelago seed \(seed)")
}
