import Foundation
import Testing
@testable import CityCore

// economy / Early solvency with the market (openspec/changes/hard-bankruptcy-grace).

/// The full sweep runs only when asked, as the weekly `rival-sweep`
/// workflow does.
private let isFullSweep = ProcessInfo.processInfo.environment["RIVAL_SWEEP"] == "1"

/// Without the market, these three seeds go bankrupt by tick 3,849.
@Test("scenario: a market-trading town stays solvent on normal", arguments: [UInt64(2), 6, 9])
func scenarioAMarketTradingTownStaysSolventOnNormal(seed: UInt64) {
    #expect(!World.botGoesBankrupt(
        layout: .archipelago, seed: seed, difficulty: .normal, tradesAtMarket: true, ticks: 4000
    ))
}

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
        print("SOLVENCY_SWEEP seed=\(seed) layout=\(layout.rawValue) bankrupt=\(bankrupt)")
        #expect(!bankrupt, "\(layout) seed \(seed)")
    }
}
