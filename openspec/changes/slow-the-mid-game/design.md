## Context

**Levers measured alone.** PlayerBot, careful order, market on, seeds 0–9 × both layouts per difficulty, 20-year cap. Medians in years; "reached" is Renaissances out of 20.

| Lever | Easy Renaissance | Normal: first merchant / 20 merchants / Renaissance (reached) | Hard Renaissance |
|---|---|---|---|
| Today | 3.3 | 3.5 / 3.5 / 3.6 (17) | 4.4 |
| Research ×4 | 3.3 | unchanged | 4.4 |
| Research ×6 | 4.8 | 3.3 / 3.3 / 4.2 (18) | 4.6 |
| **Research ×10** | **5.8** | **4.4 / 4.5 / 6.5 (18)** | **7.3** |
| Merchant gate 40 | 7.8 | 3.5 / 3.5 / 8.4 (14) | 7.7 |
| Merchant gate 60 | 9.6 | 3.5 / 3.5 / 9.5 (13) | 12.0 |
| Cloth for merchants | 5.8 | 4.8 / 4.9 / 4.9 (9) | 4.8 |

- Research ×10 is the only lever that lands Normal at 6–8 years without fewer successes.
- 20 merchants is just three merchant houses, so it lands with the first merchant under every lever.
- Higher gates separate those beats, but they cost successes and flatten Easy against Normal.

## Goals / Non-Goals

**Goals:**
- Normal: about 6–8 years to the Renaissance; Easy clearly faster, Hard slower.
- Distinct beats: tools researched → first merchant → Renaissance. A separate "20 merchants" beat waits on #223 (D3).
- Tunables in data, so a retune is a pack change.

**Non-Goals:**
- New chains (the wool → cloth change follows).
- Steam power and later eras.

## Decisions

### D1. Research ×10 in the packs

Milling 40 → 400, mining 40 → 400, metallurgy 80 → 800, cultivation 50 → 500, printing press 250 → 2,500.
- Seafaring stays at 60 for now: it gates ports and rival trade, and wasn't measured.
- Scholarship and Feudal Order are granted at a medieval start and stay as they are.

### D2. Difficulty scales research cost

`Difficulty.researchCostPercent` is 80 for Easy, 100 for Normal and 120 for Hard. `World.researchCost(of:)` is `tech.cost * percent / 100`, rounded down. Both the research system and the research panel use it.

It lives in `Difficulty` next to the other difficulty percentages (upkeep, starting balance), which is code today. A retune is a one-line change.

### D3. Sustained gate: measured, dropped

The printing press was built to need its 20 merchants held for one season: `eraGate.heldSeasons` in the packs, plus a world field recording since when the gate held.

Measured with D1 and D2, it stopped the climb:

| Difficulty | Renaissance reached of 20, D1 + D2 | With the held gate |
|---|---|---|
| Easy | 18 | 0 |
| Normal | 18 | 0 |
| Hard | 20 | 2 |

A probe of four Normal single-island games shows why:
- 20 merchants first arrive around tick 10,700.
- They never hold for more than 239 ticks in a row, against the 600 a season needs.
- The merchant count peaks at 48–72 but keeps dropping below 20 when tools run short. That is the collapse filed as #223.

The keep-or-drop rule says drop. The mechanism is removed rather than left in the code unused. It can return as data once #223 steadies the merchants.

### D4. Measurement

- The pacing sweep runs the careful order with the market on.
- The first-hour sweep (guided Hard start, 5 years) and the rival viability sweep must stay green. Neither the guided bot nor rivals research.

## Results

Careful order, market on, seeds 0–9 × both layouts per difficulty, 20-year cap; medians in years:

| Difficulty | First merchant | 20 merchants | Renaissance | Reached of 20 | Bankrupt |
|---|---|---|---|---|---|
| Easy | 3.2 | 3.2 | 4.9 | 18 | 0 |
| Normal | 4.4 | 4.5 | 6.5 | 18 | 1 |
| Hard | 6.5 | 6.5 | 8.0 | 20 | 0 |

Today the numbers are Easy 3.3, Normal 3.6 and Hard 4.4 years, with 18, 17 and 20 reached. Normal lands inside the 6–8-year target. Easy is now clearly faster and Hard slower. The first merchant and the Renaissance are 1.4–2.0 years apart.
