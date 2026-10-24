## 1. History in CityCore

- [x] 1.1 Tests-first: ring bound, sparse maps, rollover, Codable round trip, missing key decodes empty
- [x] 1.2 `Statistics.swift`: `StatisticsHistory`, `SeasonStatistics`, `GoodFlow`, `MoneyFlow`, `ProducerActivity`
- [x] 1.3 Tests-first: made, used, sold, bought, tax, upkeep, trade, fuel, construction and house consumption
- [x] 1.4 `World+Statistics.swift`: `runStatisticsSystem(events:)`, called last in `tick()`; the hook in `consumeIfDue`
- [x] 1.5 Tests-first: producer sampling (working, waiting, stuck with its good, blocked)
- [x] 1.6 Boundary snapshot: stock, residents by tier, balance, rivals
- [x] 1.7 Determinism: two replays equal, save and load mid-season equal, `DeterminismFixture` identical across two macOS runs (Linux is CI's compare job)
- [x] 1.8 `WorldSnapshot.statistics`

## 2. The sheet

- [x] 2.1 Tests-first: `StatisticsViewModel` series for each tab
- [x] 2.2 `StatisticsSheet` (Goods, Money, People, Rivals) with Swift Charts; the HUD button; Apple TV entry and focus
- [x] 2.3 Launch flags `-uiTestSeasons n` and `-uiTestOpenStatistics [tab]`; window shots on the Mac. Apple TV and iPhone are compiled, not run: no simulator slot

## 3. design/web

- [x] 3.1 `StatisticsPanel` component, the `chart.xyaxis.line` icon, a preview; `npm run typecheck` and `npm run build`

## 4. After `per-good-storage` merges

- [ ] 4.1 Merge main in; pin the stuck rule against `.outputStuck`; show the "stopped" counts from it
