## 1. M1 — Rivals spend on houses first

- [x] 1.1 Rebase on any open forestry rival PR that touches `Systems/RivalSystem.swift`, so the threshold rules change in one place
- [x] 1.2 Tests-first: translate the `rival-towns` / Rival build order scenarios "A farm for every house", "Reserve keeps money for the first houses", "Houses and the first sawmill ignore the reserve", "Sawmill before planks run out", "Foresters wait for the town" and the changed "Rival replants beside its hut" and "Rival forester needs open ground beside a hut" into failing swift-testing tests in CityCoreTests; confirm red
- [x] 1.3 Implement to green: `rival-towns` / Rival build order — the farm-per-house food rule (design D4) and the forester gate on opening and 4 houses (design D3)
- [x] 1.4 Implement to green: `rival-towns` / Rival build order — the sawmill-first rule (design D2) and the $150 house-first reserve with its exemptions (design D1), counting houses with residents from the rival's populations in entity order
- [x] 1.5 Update rival tests that relied on the old food ratio or on foresters during the opening (`RivalAITests`, `RivalForestryTests`)
- [x] 1.6 Run the rival sweep harness (seeds 0–9, Easy/Normal/Hard, 36,000 ticks, release) and record rivals at 0 residents, residents and treasury per year in design "Evidence"
- [x] 1.7 Run `DeterminismFixture` twice at each length with `SWIFT_DETERMINISTIC_HASHING=1`, confirm byte-identical output, and regenerate the `game-data-codegen` baseline in its own commit that says why
- [x] 1.8 Refactor under a green bar
- [x] 1.9 Run `SCENARIO_COVERAGE_STRICT=1 make test-scenarios` and confirm no uncovered scenario in `rival-towns` from this milestone

## 2. M2 — Rivals at the market (requires `add-town-market` archived)

- [x] 2.1 Archive `add-town-market` (or confirm it is archived) so `openspec/specs/town-market` exists. Then add a `town-market` delta to this change that replaces "Rivals stay off the market" with a requirement that player trades leave rivals alone, keeping the scenario "Market trade leaves rivals alone"; run `openspec validate rival-ai-viability --strict`
- [x] 2.2 Tests-first: translate every `rival-towns` / Rival market trades scenario into failing tests; confirm red
- [x] 2.3 Implement to green: per-rival seasonal market counts on the rival (Codable, optional on decode), reset with the season like the player's
- [x] 2.4 Implement to green: a rival market command applied at the tick boundary in queue order, reusing the market's price and fill rules, with no `marketTraded` event and no change to the player's counts
- [x] 2.5 Implement to green: the rival market step before the threshold rules — unblock, pay debts, feed, in that order (design D5)
- [x] 2.6 Add a save round-trip test for the rival counts and a CityPersistence load test for a save without them
- [x] 2.7 Re-run the rival sweep and record it in design "Evidence"; regenerate the determinism baseline as in 1.7
- [x] 2.8 Refactor under a green bar
- [x] 2.9 Run `SCENARIO_COVERAGE_STRICT=1 make test-scenarios` and confirm no uncovered scenario in `rival-towns` or `town-market` from this milestone

## 3. M3 — Caps by difficulty and the viability check

- [x] 3.1 Tests-first: translate "House cap", "Building cap ignores foresters and roads" and `rival-towns` / Rival viability "Rivals are viable across seeds" into failing tests; confirm red
- [x] 3.2 Implement to green: house and building caps per difficulty as `Difficulty` properties next to `rivalCount`, with foresters and roads left out of the building count (design D6)
- [x] 3.3 Add the viability tests: seed 0 at each difficulty for 7,200 ticks (3 years) in the default suite, checking that no rival empties after year 2 or stays in debt for a year; and the scenario sweep (seeds 0–9, 36,000 ticks, year-5 floors) behind `RIVAL_SWEEP=1`, run by the weekly `rival-sweep` workflow
- [x] 3.4 Tune the caps and the reserve against design D7 using the full sweep; record the final numbers in design "Evidence"
- [x] 3.5 Check the "replayed rival game" tick budget on Hard with the 64-building cap; run the `add-forestry` player playtest bot next to the rivals on archipelago seed 7 and record player against rival residents for the Island Rivalry goal
- [x] 3.6 Regenerate the determinism baseline as in 1.7
- [x] 3.7 Refactor under a green bar
- [x] 3.8 Run `SCENARIO_COVERAGE_STRICT=1 make test-scenarios` and confirm no uncovered scenario in `rival-towns` from this change
