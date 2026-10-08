## 1. M1 — Tiers in CityCore

- [ ] 1.1 Tests-first: translate every scenario under population-and-needs (tiers, advancement, decline, taxes, consumption) and the bakery scenarios from goods-and-production and buildings-and-construction into failing tests in `CityCoreTests`. Confirm red.
- [ ] 1.2 Implement to green: `HouseTier`, tier and streak on `HousePopulation` with save-compatible decoding, generic needs, advancement/decline, per-tier tax and consumption (design D1–D3).
- [ ] 1.3 Implement to green: `Good.bread`, `BuildingKind.bakery`, its spec, recipe and stockpile capacity (D4).
- [ ] 1.4 Refactor under a green bar; update tests that assumed peasants consume planks.

## 2. M2 — Rendering and UI

- [ ] 2.1 Tests-first: translate `#### Scenario: Merchant house uses the tier 3 sprite` and `#### Scenario: Tier change swaps the house sprite` into failing tests in `CityRender2DTests`, plus an inspector test for tier lines. Confirm red.
- [ ] 2.2 Implement to green: `houseTiers` on the snapshot, tier in the sprite spec and texture lookup (D5); inspector tier and needs lines; bakery in the palette and switches.
- [ ] 2.3 Draw the tier-2 and tier-3 houses, the bakery and the bread icon procedurally; run `make sprites-procedural` and `make sprites-verify`.

## 3. M3 — Verification

- [ ] 3.1 Runtime check on a dedicated simulator: a house with food and planks becomes citizens and changes sprite; a bakery fed by the town center produces bread.
- [ ] 3.2 Run lint, format, `make test-scenarios` and `openspec validate add-population-tiers --strict`.
