## Context

Stores (town centers, warehouses, ports) hold one pool shared by every good. On main, a carrier that reaches a full store drops its goods, and that loss has been working as a hidden cap. #232 makes goods lossless and sends them straight to consumers. With nothing lost, a good no one uses yet fills the shared pool and blocks everything else. In the probe game, bread reaches 228 of 240 storage before the first merchant. Iron can't ship, no tools get made, and the town never reaches merchants. Pacing on #232 fell from 121 to 25 of 180 arms reaching a merchant.

The owner's model (memory: storage backpressure) is per-good storage, producers that stop when their output has nowhere to go, and Anno-style status icons for it.

## Goals / Non-Goals

**Goals:**
- No good can crowd another out of a store.
- Output leaves a producer only for somewhere that takes it, so nothing is lost and a blocked producer stops visibly.
- No worse than main on pacing, bankruptcies, solvency and rival viability, on main alone, before #232 lands on top.
- Normal keeps 6–8 years to the Renaissance.

**Non-Goals:**
- Hops and lossless redirects. They are #232's, which lands after this.
- Market sales as an automatic output destination. Selling at the market stays a player action. It frees room like any other draw.
- Per-good limits for producer or house stockpiles.

## Decisions

### D1. A per-good mode in `Stockpile`, set by data

- `Stockpile` gains `limitsEachGood`. In that mode, `capacity` limits each good on its own. `room(for:)` answers "how many more of this good fit" for both modes.
- `freeSpace` stays as the room summed over every good. Callers that know the good use `room(for:)`.
- Stores declare `storagePerGood` in the pack instead of `storage`. The validator rejects a building that sets both.
- `World.newStockpile(for:)` builds the right kind of stockpile, replacing `stockpileCapacity(for:)`.
- One type keeps saves, carriers and tests working with a single shape, so no second store type is needed.
- **N:** the town center holds 40 per good, as its whole store did before. The warehouse and the port hold 80 per good, against 200 shared before.
  - A town with a town center and one warehouse holds up to 120 of each good, so storage is no longer what limits growth.
  - 40/80 met every bar on the first run (D7), so no other values were swept.

### D2. Backpressure: ship only where there is room, counting what is on its way

- A producer picks the nearest store whose room for the good is greater than the units of that good already on their way to it.
- Inbound units are counted once per tick from the carriers in flight and updated as each carrier is spawned. Without that, eight sawmills would all aim at the last free plank slot.
- With no destination, the output stays in the producer's own stockpile. Production already stalls when that stockpile can't take a cycle's output, so the producer stops by itself and resumes when room opens.
- Nothing new is dropped. A carrier can still find its store full on arrival if a market purchase, a ship or a harvest filled it meanwhile; main's existing drop-on-arrival remains for that case, and #232's redirects replace it.

### D3. "Output stuck" replaces "Store full"

- `BuildingIssue.storageFull` becomes `.outputStuck(Good)`. It names the good the producer holds most of; on a tie, the first in catalog order.
- The inspector reads "Output stuck: no room for bread". The status icons (art2) map it to their good-plus-pause pictogram.
- The issue's place in the check order is unchanged.

### D4. The rest rule goes

- **Measured on main 6559bd9d, per-good storage, no hops, pacing sweep:** rest rule on: 173/180 arms reach a merchant, 0 bankruptcies. Rest rule off: 173/180, 0 bankruptcies.
  - Medians match within a tenth of a year.
- Per-good limits cap every good, including the bread that resting never covered, so the rule adds nothing.
- Removed: `restAt`, `IslandRestContext`, `restContexts`, `isResting`, `BuildingIssue.resting`, and the inspector's resting line.
- `needsSupply` goes back to stock plus inbound against twice the recipe amount.

**Rejected alternative: resting on house-only goods.** This variant also rested a producer of a good no building takes, using the shared stores.
- On main, it made pacing worse: 84/180 arms reached a merchant, with 31 bankruptcies, against 121 and 13.
- On #232 with hops off, it was worse still: 49/180, with 32 bankruptcies.

### D5. Rivals read room per good

- **First warehouse:** a rival's town center counts as full when it has room for fewer than 4 food, which is what stops the farms. The rival then builds its first warehouse.
- **Surplus sales:** a rival sells planks or wood when its stores have room for fewer than 20 more of that good, keeping 60. This replaces the 40 units of shared room.
- **Removed:** the debt-or-clear sale's "full and starving" trigger, and the "no purchase into a full town center" rule. With per-good stores a town center can't be full of food and short of it at once, and other goods can't block a food purchase. Purchases are limited by the town center's room for the good bought.
- Rival viability is re-measured below.

### D6. Research retune: ×18

- Per-good storage speeds the climb. Careful Normal reached the Renaissance in a median of 5.5 years, against main's 6.3.
- The techs `rest-when-stocked` D3 retuned move from ×14 to ×18 of their original costs: milling 720, mining 720, metallurgy 1,440, cultivation 900, printing press 4,500.
- **Pacing sweep, per-good storage on main, no hops, factor relative to today's ×14:**

| Variant | Careful Renaissance median (Easy / Normal / Hard) | All arms, Normal median | Arms reaching a merchant | Bankrupt |
|---|---|---|---|---|
| main 6559bd9d | 4.9 / 6.3 / 7.8 | 7.4 | 118 / 178 | 14 |
| per-good, ×14 | 4.65 / 5.5 / 7.2 | 5.4 | 173 / 180 | 0 |
| per-good, ×18.2 (130%) | 5.3 / 6.5 / 7.6 | 6.5 | see D7 | 0 |
| per-good, ×22.4 (160%) | 5.7 / 6.75 / 8.45 | 6.9 | 170 / 180 | 0 |

- ×18 keeps careful Normal at main's pace, with Easy faster and Hard slower.

### D7. Measurement (final configuration)

Release sweeps with `RIVAL_SWEEP=1`, main 6559bd9d against this change, same seeds, all three play orders:

| | main | per-good storage |
|---|---|---|
| Arms reaching a merchant (of 180) | 120 | 170 |
| Bankrupt (of 180) | 14 | 0 |
| Merchant reached: careful / naive / following hints (of 60) | 56 / 30 / 34 | 57 / 56 / 57 |
| Careful Renaissance median, Easy / Normal / Hard | 4.9 / 6.3 / 7.8 | 5.3 / 6.4 / 7.6 |
| All arms, Normal Renaissance median | 7.4 | 6.4 |
| Market-trading solvency (of 20) | 0 bankrupt | 0 bankrupt |
| Guided Hard start: bankrupt; residents min / median | 0/20; 29 / 55 | 0/20; 97 / 110 |
| Rivals: year 5 min / median; year 15 median | 15 / 60; 56.5 | 20 / 56; 56 |

### D9. The no-market control checks that the market does no harm

- The control used to require that at least 2 of 30 towns without the market go bankrupt by tick 4,000. Per-good storage ends the store clog that bankrupted them: 0 of 30 do now, with or without the market. A control that requires bankruptcies would demand the bug back.
- **New control:** with the market, towns go bankrupt no more often and house no fewer residents than without it. Measured: 0 / 0 bankrupt, 992 / 990 residents across the 30 games.
- **What the market adds now** (pacing sweep with `PACING_FULL=1`, 180 paired arms each):
  - First merchant, median over all arms: 4.7 years with the market, 5.5 without. Paired, the market brings the first merchant a median 0.2 years sooner (mean 0.45).
  - Arms reaching a merchant: 170 with the market, 173 without. The three extra misses are all on archipelago seed 7, which struggles either way.
  - Bankruptcies: 0 either way.
- The market's value is small and mixed, so no positive-value threshold is set. The question goes to the M2 market and porters work (issue linked in the PR).

### D8. Save migration v9 → v10

- Each town center, warehouse and port takes its kind's per-good limit and keeps every unit.
- A good above the limit stays as overflow: its room is 0 until enough is used, so nothing is lost on load.
- The fixture `v9_single_island.json` has a town center holding 55 planks.

## Risks / Trade-offs

- **More storage overall:** a town holds far more goods in total, up to 120 of each good with one warehouse. Stores rarely limit the town now. Pacing is the check, and it's tuned.
- **Rivals stockpile more before selling surplus.** Viability is re-measured.
- **Spec sequencing:** this change replaces requirements that the active changes `rival-surplus-sales`, `rival-viability-margin` and `market-buys-use-island-stores` modify. Archive those first.

## Migration Plan

- Lands on main first, without hops.
- #232 then merges main. Its no-op save migration becomes v10 → v11. It re-measures on top, with per-good storage in place.
