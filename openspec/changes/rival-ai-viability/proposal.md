## Why

Rivals are not yet a credible presence. On current `main`, which has forestry, the market and fair starts, a headless sweep ran archipelago seeds 0–9 at Easy, Normal and Hard for 15 in-game years (36,000 ticks, 60 rivals in all, with the player passive and kept solvent). It found:

- **28 of 60 rivals never get going.** They end with 0 residents and a treasury sliding toward −$1,334. That is every Easy rival (10 of 10), 6 of 20 on Normal and 12 of 30 on Hard. Each one spends its starting treasury on roads, huts, foresters and a sawmill before a house pays tax. Then upkeep takes it into debt, and a rival in debt waits forever.
- **The other 32 rivals stall by year 3.** Every one hits the 50-building cap with about 16 houses, because foresters and farms fill 20 of the 50 slots. Their residents hold at a median of about 30. Food sits at 0, and 5 houses in each town stand empty. Treasuries pile up unspent: a median of $24,000 on Normal and up to $77,000. None reaches the merchant tier.

So the "outgrow every rival" goal is met for free on Easy, and on Normal or Hard it means beating a town that stops at about 30 residents.

## What Changes

- **BREAKING (rival AI):** until a rival has 3 occupied houses, every step except a house, a farm or a sawmill needed for planks keeps a $150 reserve, so the first houses are always affordable.
- **BREAKING (rival AI):** the forester rule waits until the opening is complete and the rival has 4 houses.
- **BREAKING (rival AI):** the farm rule keeps one farm per house instead of four per five houses.
- **BREAKING (rival AI):** a rival with no sawmill and too few planks for a house builds a sawmill first, so planks cannot run out for good.
- **BREAKING (rival AI):** rivals trade at their own town center's market, as a safety valve only. A rival in debt or below its reserve sells surplus. A rival blocked on wood, planks or food buys a little. Prices and seasonal limits are the player's; the counts are kept per rival. The market's own spec still says rivals stay off it, so this changes that rule.
- **BREAKING (rival AI):** the house cap and the building cap scale with difficulty: 16 and 32 buildings on Easy, 24 and 48 on Normal, 32 and 64 on Hard. Foresters and roads do not count toward the building cap.
- A viability requirement and seed-sweep tests: no rival is left at 0 residents after its second year, no rival stays in debt for a whole year, and each difficulty meets a residents target by year 5.

Out of scope: new building kinds for rivals (a citizen or merchant chain), spending a rival's surplus treasury on something new, rival ports and trade (`rival-trade` is unchanged), and AI personalities.

## Capabilities

### New Capabilities
- (none)

### Modified Capabilities
- `rival-towns`: "Rival build order" gains the reserve, the forester gate, the farm ratio, the sawmill rule and the difficulty caps. New requirements are "Rival market trades" and "Rival viability".

## Impact

- **CityCore**: `Systems/RivalSystem.swift` (threshold rules, reserve, caps), a rival market step in the same system, a new `Command` case for rival market trades applied at the tick boundary like `rivalPlace`, and per-rival market counts in `RivalTown` or beside it. Saves gain the per-rival counts; older saves load with zero counts, as the player's counts do.
- **Market spec**: `add-town-market`'s "Rivals stay off the market" forbids rivals from trading. M2 depends on that change being archived first; it then replaces the requirement with one that says player trades leave rivals alone. Until then, the `town-market` delta cannot be written against a base spec, so it is a task and not part of this proposal's deltas.
- **Overlap**: the forestry work also changes `RivalSystem.swift`. Land this after any open forestry rival PR, or rebase on it.
- **Determinism**: every archipelago game with rivals plays out differently, so the `DeterminismFixture` output and the `game-data-codegen` baseline change on purpose in each milestone that changes rival behaviour. Rival steps stay free of the world RNG and of `Dictionary` order.
- **Tests**: rival tests that pin the opening's money or the 50-building cap move with the new rules.
- No new build-time tools.
