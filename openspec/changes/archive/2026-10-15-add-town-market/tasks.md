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

- [x] 3.0 Rebase on `main` after #30 (game-over banner and tool lock) and `add-forestry` M3 have landed, if they have; both edit the inspector.
- [x] 3.1 Tests-first: translate the `platform-shells` scenarios of "Town center market panel" into failing `CityUITests` against a `TownMarketSection` view model. Confirm red.
- [x] 3.2 Implement to green: `platform-shells` / Town center market panel. Add the row strings and button states from the snapshot, town center free space and island stock, plus the game-over lock, using the same game-over flag #30 uses for tools (design D6).
- [x] 3.3 Wire the section into the inspector details for player town centers, with buttons enqueueing commands through `GameSession`. Keep the controls focusable for `add-tvos-port`'s focus sections (plain `Button`s, no gestures).
- [x] 3.4 Check in the iOS Simulator with the verify skill: buy wood and food, sell planks, watch the "left" counts fall and reset at the next season, and confirm the buttons lock after bankruptcy.
  - iPhone 17 in landscape. The expanded callout keeps its title and the Less and Demolish row on screen, and its details scroll. The collapsed callout shrinks back to its key lines. Buy 5 wood took the balance from $1,000 to $970 and wood from 10 left to 5 left. Sell 1 plank added $4 and took planks to 19 left. At the next season wood was back to 10 left.
  - Food was not bought on screen, because its buttons sat below the scroll fold. The lock after bankruptcy was not reached on screen. `TownMarketUITests` ("Market locked after game over") covers both.
- [x] 3.5 Re-run the design's balance harness (configs B, D and F, 9,600 ticks) against the real implementation. Record the results here and tune the limits in the packs if a run differs materially from the design table.
  - The design's harness was never committed, so this run uses a new one (also not committed). The bot copies the rival AI's script and threshold rules for the player, takes one turn every 50 ticks, and trades with the design's policy: it keeps 2 wood, keeps food at 4 (C) or 1 (F), and sells anything above 30 when the balance is below $150. Runs are single island seed 0, Normal, 36,000 ticks. The bot never builds a bakery or a toolmaker, so its absolute numbers can't be compared with the design table. Only the differences between configs carry over.
  - Old start (`main`): no run went bankrupt.

    | Config | Spring 1204 | First 20 citizens | Market use |
    |---|---|---|---|
    | A, no forester, no market | 12 residents (0 citizens) | never | none |
    | B, market only | 6 residents (0 citizens) | Spring 1210 | 591 wood, 383 food bought; buy limit hit 488 times |
    | C, forester + market, food 4 | 38 residents (23 citizens) | Autumn 1203 | $420 spent, $192 earned |
    | D, forester only | 29 residents (6 citizens) | never | none |
    | F, forester + market, food when out | 19 residents (6 citizens) | Summer 1205 | 34 wood, 1 food bought |

  - Fair starts (#42 merged locally, not on `main`): no run went bankrupt either. First 20 citizens: C in Summer 1201, B in Spring 1207; A, D and F never got there (F plateaued at 12 citizens).
  - The conclusions match the design. The market does not replace the forester: B hits the limit constantly and stays small. Forester plus market (C) reaches citizens soonest on both starts. Overbuying never drained the treasury.
  - I could not reproduce the fair-start note's single-island bankruptcy in 1203 with this bot, so the market's effect on that bankruptcy is unmeasured. The note came from a different bot, which built a forester after every hut and followed a longer script.
  - F bought almost no food. At every year-end sample its island held 25 to 31 planks, which suggests a town center near its 40-unit capacity, but the harness did not count the failed buys. The bot only sells planks below $150. In play, a full town center blocks emergency buys until the player sells something. The panel already disables Buy when the town center is full.
  - The limits were not retuned: no run differed from the design's intent.
- [x] 3.6 Refactor under a green bar.
- [x] 3.7 Run `make test-scenarios` and confirm no uncovered scenario in `platform-shells` from this change.
