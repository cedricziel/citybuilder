## 1. M1 — Market terms as content

- [x] 1.1 Tests-first: add failing `GameDataGen` tests for an optional `market: { buy, sell }` on `Good` items: both default to 0, negative values and unknown keys are rejected, and the emitter writes `Good.marketTerms`. Add failing CityCore tests for the `town-market` scenarios "Basic goods can be bought" and "Chain goods cannot be bought". Confirm red.
- [x] 1.2 Extend `pack.schema.json`, the GameDataGen model, validator and Swift emitter for `market`; keep the emitted output deterministic.
- [x] 1.3 Content: set `market: { buy: 10, sell: 20 }` on wood, planks and food and `market: { sell: 20 }` on every other good in `core.yaml` and the four culture packs. Run `make gamedata` and commit the regenerated Swift. Confirm `make gamedata-check` is clean.
- [x] 1.4 Refactor under a green bar.
- [x] 1.5 Run `make test-scenarios` and confirm no uncovered scenario in `town-market` / Market terms are content.

## 2. M2 — Trading in the simulation

- [x] 2.1 Tests-first: translate every remaining scenario in `specs/town-market` and `specs/economy` into failing swift-testing tests in `CityCoreTests`, including a save/load round trip and a decode of a save without `market`. Confirm red.
- [x] 2.2 Implement to green: `town-market` / Market prices. Add the market spreads next to the rival spreads (design D2) and a test-only check that walks every good and channel for the no-loop rule.
- [x] 2.3 Implement to green: `town-market` / Buying at the town center and Selling at the town center. Add the `marketBuy` and `marketSell` commands, buffer order by entity ID, and partial fills (design D1, D5).
- [x] 2.4 Implement to green: `town-market` / Seasonal limits reset and persist. Add `World.market` with `Codable` decoding as empty when missing, and reset it on the season-change tick (design D4).
- [x] 2.5 Implement to green: `town-market` / Market trades are reported, and Rivals stay off the market. Add `marketTraded` (with the CLI `WorldEventJSON` case), `WorldSnapshot.market`, and the game-over guard.
- [x] 2.6 Implement to green: `economy` / Market money is not tax or upkeep.
- [x] 2.7 Refactor under a green bar: put the market in `World+Market.swift` and keep `World.apply` within SwiftLint's complexity limit.
- [x] 2.8 Run `make test-scenarios` and confirm no uncovered scenario in `town-market` or `economy` from this change. Run `scripts/check-no-apple-ui-imports.sh`. Confirm the macOS and Linux `DeterminismFixture` outputs still match in CI.

## 3. M3 — Market panel

- [ ] 3.0 Rebase on `main` after #30 (game-over banner and tool lock) and `add-forestry` M3 have landed, if they have; both edit the inspector.
- [ ] 3.1 Tests-first: translate the `platform-shells` scenarios of "Town center market panel" into failing `CityUITests` against a `TownMarketSection` view model. Confirm red.
- [ ] 3.2 Implement to green: `platform-shells` / Town center market panel. Add the row strings and button states from the snapshot, town center free space and island stock, plus the game-over lock, using the same game-over flag #30 uses for tools (design D6).
- [ ] 3.3 Wire the section into the inspector details for player town centers, with buttons enqueueing commands through `GameSession`. Keep the controls focusable for `add-tvos-port`'s focus sections (plain `Button`s, no gestures).
- [ ] 3.4 Check in the iOS Simulator with the verify skill: buy wood and food, sell planks, watch the "left" counts fall and reset at the next season, and confirm the buttons lock after bankruptcy.
- [ ] 3.5 Re-run the design's balance harness (configs B, D and F, 9,600 ticks) against the real implementation. Record the results here and tune the limits in the packs if a run differs materially from the design table.
- [ ] 3.6 Refactor under a green bar.
- [ ] 3.7 Run `make test-scenarios` and confirm no uncovered scenario in `platform-shells` from this change.
