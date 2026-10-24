## Context

**Trace** (careful scripted player, Normal, seed 0, single island, research ×10):
- **Merchants:** 37 at year 4.5, 0 at year 5.0.
- **Tools:** made at 16–22 a year against a toolsmith's 40, because the toolsmith waits for iron, the smelter for charcoal, and the burner for wood.
- **Wood vs planks:** wood sits at 0 while planks pile up to 100–180.

Supply carriers serve producers in entity order (`spawnSupplyCarriers`). The early sawmills take each log, and nothing tells them the town has enough planks.

## Goals / Non-Goals

**Goals:**
- Stop a producer from drawing inputs once its output is plentiful, so the inputs reach the buildings that need them.
- Make the pause readable: calm, idle, named.
- Keep Normal at 6–8 years to the Renaissance.

**Non-Goals:**
- General production priorities.
- Food and luxury throughput (next measurement).
- The sustained-merchants gate (re-measured after this).

## Decisions

### D1. Rest level per good, in data

- `restAt` is an optional field on a `Good` pack item.
- A producer rests when every output good declares `restAt` and the owner's operational town centers, warehouses and ports hold at least that much of it in total.
- Producers with no inputs (lumberjacks, farms, gardens) never rest, so wood, food and raw goods keep flowing; the idle-good hint covers raw goods piling up.
- 40 matches the town center's whole store, so a single store never rests a producer unless it is full of that one good.
- Ships, the shipyard and projects make no stored goods, so they never rest.

### D2. One predicate, both paths

- `World.isResting(_ producer: Building) -> Good?` returns the first output good it rests on.
- `needsSupply` returns false for a resting consumer. Supply dispatch asks it today, and walkers' #232 direct hops (producer → producer) ask it too, so one check covers both routes whichever lands first.
- Callers sum the owner's stores once per pass and pass the totals in; `needsSupply` checks resting last, after the cheap carrier and on-hand checks.

### D3. Research retune: ×14

Resting brings the Renaissance about a year sooner on Normal (6.5 → 5.3 years with research ×10). The medieval techs and the printing press move from ×10 to ×14 of their original costs: milling 560, mining 560, metallurgy 1,120, cultivation 700, printing press 3,500.

Careful scripted player, market on, seeds 0–9 × both layouts per difficulty, run to year 10:

| Variant | Renaissance (median years: Easy / Normal / Hard) | Reached of 60 | 20+ merchants at year 10 | Held share, years 8–10 | Bankrupt |
|---|---|---|---|---|---|
| Today (×10, no resting) | 4.9 / 6.5 / 8.0 | 56 | 8 | 0.06 | 0 |
| Resting, ×10 | 4.1 / 5.3 / 6.4 | 57 | 6 | 0.26 | 0 |
| Resting, ×12 | 4.6 / 5.8 / 6.8 | 55 | 14 | 0.29 | 1 |
| **Resting, ×14** | **4.9 / 6.8 / 7.8** | **54** | **12** | **0.31** | **0** |

×14 keeps Normal inside 6–8 years and keeps Easy clearly faster and Hard slower. Hard reaches the Renaissance in 17 of 20 starts instead of 20. These numbers are from before walkers' #232 (direct hops, no more goods lost at a full store). This change lands first; #232 re-measures pacing on top of it, and the factor is adjusted if Normal leaves 6–8 years.

### D4. Visible and idle

- `BuildingIssue.resting(Good)` is checked after the route to storage and before missing inputs, since a resting producer is also short of inputs.
- The inspector shows it as "Resting: stores hold plenty of planks": no warning symbol and no "Problem:" prefix.
- Rendering already treats a building with any issue as idle: no chimney smoke, no window glow, and no working animation.

### D5. The no-market control counts over 30 seeds

Resting keeps archipelago seeds 6 and 21 solvent without the market, so the `hard-bankruptcy-grace` control, which named four seeds that all went bankrupt, failed. Swapping in other seeds that still fail would bend the test to the result. The control now counts bankruptcies over archipelago seeds 0–29 on Normal at 4,000 ticks: at least 2 of 30 without the market and at most 1 of 30 with it. Measured with resting: 4 of 30 without (seeds 2, 9, 11, 27) and 0 of 30 with, so each threshold leaves a margin.
