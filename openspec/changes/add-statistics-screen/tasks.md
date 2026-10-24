## 1. History in CityCore

- [ ] 1.1 Tests-first: ring bound, sparse maps, rollover, Codable round trip, missing key decodes empty
- [ ] 1.2 `Statistics.swift`: `StatisticsHistory`, `SeasonStatistics`, `GoodFlow`, `MoneyFlow`, `ProducerActivity`
- [ ] 1.3 Tests-first: made, used, sold, bought, tax, upkeep, trade, fuel, construction and house consumption
- [ ] 1.4 `World+Statistics.swift`: `runStatisticsSystem(events:)`, called last in `tick()`; the hook in `consumeIfDue`
- [ ] 1.5 Tests-first: producer sampling (working, waiting, stuck with its good, blocked)
- [ ] 1.6 Boundary snapshot: stock, residents by tier, balance, rivals
- [ ] 1.7 Determinism: two replays equal, save and load mid-season equal, `DeterminismFixture` unchanged on macOS and Linux
- [ ] 1.8 `WorldSnapshot.statistics`

## 2. The sheet

- [ ] 2.1 Tests-first: `StatisticsViewModel` series for each tab
- [ ] 2.2 `StatisticsSheet` (Goods, Money, People, Rivals) with Swift Charts; the HUD button; Apple TV entry and focus
- [ ] 2.3 Launch seed for screenshots (`-uiTestSeedLived`) and window shots on the Mac

## 3. design/web

- [ ] 3.1 `StatisticsPanel` component, the `chart.xyaxis.line` icon, a preview; `npm run typecheck` and `npm run build`

## 4. After `per-good-storage` merges

- [ ] 4.1 Merge main in; pin the stuck rule against `.outputStuck`; show the "stopped" counts from it
