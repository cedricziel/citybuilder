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
- A producer rests when every output good declares `restAt` and the owner's operational town centers, warehouses and ports on the producer's island hold at least that much of it in total.
- Totals are per island because stores never feed another island's construction sites. With owner-wide totals, an outpost sawmill rested on the home island's planks while the outpost's own house waited for planks for good (found in review).
- A producer rests only while another kind of building on its island takes one of its inputs (recipe input or fuel). Resting exists to free inputs for those buildings; a town with sawmills and no charcoal burner gains nothing from idle sawmills. A first version without this condition took the naive scripted players from 10 to 27 bankruptcies at ×10 and stopped plank income they live on (D3).
- Producers with no inputs (lumberjacks, farms, gardens) never rest, so wood, food and raw goods keep flowing; the idle-good hint covers raw goods piling up.
- 40 matches the town center's whole store, so a single store never rests a producer unless it is full of that one good.
- Ships, the shipyard and projects make no stored goods, so they never rest.

### D2. One predicate, both paths

- `World.isResting(_ producer: Building) -> Good?` returns the first output good it rests on.
- `needsSupply` returns false for a resting consumer. Supply dispatch asks it today, and walkers' #232 direct hops (producer → producer) ask it too, so one check covers both routes whichever lands first.
- Supply dispatch builds an `IslandRestContext` per owner and island once per pass (store totals and the kinds of building that take each input), passes the consumer's island context in, and subtracts each unit it dispatches so the totals stay current. `needsSupply` checks resting last, after the cheap carrier and on-hand checks.

### D3. Research retune: ×14

Resting brings the Renaissance about a year sooner on Normal for the careful player. The medieval techs and the printing press move from ×10 to ×14 of their original costs: milling 560, mining 560, metallurgy 1,120, cultivation 700, printing press 3,500.

Pacing sweep, market on, seeds 0–9 × both layouts × three difficulties per order (60 arms), run to year 10, on main 4f3e8a0c:

| Variant | Careful: Renaissance median (Easy / Normal / Hard) | Careful: 20+ merchants at year 10 | Careful: held share, years 8–10 | Naive: Renaissance reached | Hint-following: Renaissance reached | Arms reaching a merchant (of 180) | Bankrupt (of 180) |
|---|---|---|---|---|---|---|---|
| main (×10, no resting) | 4.9 / 6.5 / 8.0 | 8 | 0.06 | 28 | 34 | 121 | 10 |
| Resting without the shared-input condition, ×10 | 4.1 / 5.3 / 6.4 | 10 | 0.26 | 7 | 11 | 74 | 27 |
| Resting without the shared-input condition, ×14 | 4.9 / 7.1 / 8.3 | 2 | 0.27 | 0 | 0 | 53 | 33 |
| Resting, shared input, ×10 | 4.0 / 5.4 / 6.3 | 11 | 0.29 | 32 | 37 | 126 | 9 |
| **Resting, shared input, ×14** | **4.9 / 6.3 / 7.8** | **11** | **0.29** | **31** | **32** | **121** | **8** |

×14 keeps careful Normal inside 6–8 years, Easy clearly faster and Hard slower; careful Hard reaches the Renaissance in 19 of 20 starts. Naive and hint-following players do not regress against main: as many arms reach a merchant, bankruptcies fall from 10 to 8, and the Renaissance count stays within three arms (naive 28 → 31, hint-following 34 → 32). Two careful archipelago arms go bankrupt (Hard seed 2 at year 8.0; Normal seed 5 at year 9.1, which never reaches a merchant on main either).

"20+ merchants at year 10" samples one tick, while the held share counts every turn in years 8–10. Resting moves towns from a brief peak to hovering around 20 merchants: the 10–19 bucket at year 10 grows (6 → 16 careful arms), so a single-tick sample can miss the 20 line while the held share rises.

These numbers are from before walkers' #232 (direct hops). This change lands first; #232 re-measures pacing on top of it, and the factor is adjusted if Normal leaves 6–8 years.

### D4. Visible and idle

- `BuildingIssue.resting(Good)` replaces missing inputs for a resting producer. While it still works off inputs on hand it has no issue, so it is not drawn cold while it works.
- The inspector shows it as "Resting: stores hold plenty of planks": no warning symbol and no "Problem:" prefix.
- Rendering already treats a building with any issue as idle: no chimney smoke, no window glow, and no working animation.

### D5. The no-market control counts over 30 seeds

Resting keeps archipelago seeds 6 and 21 solvent without the market, so the `hard-bankruptcy-grace` control, which named four seeds that all went bankrupt, failed. Swapping in other seeds that still fail would bend the test to the result. The control now counts bankruptcies over archipelago seeds 0–29 on Normal at 4,000 ticks: at least 2 of 30 without the market and at most 1 of 30 with it. Measured with resting: 4 of 30 without (seeds 2, 9, 11, 27) and 0 of 30 with, so each threshold leaves a margin.
