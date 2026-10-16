## Context

The `rival-ai-viability` sweep (archipelago seeds 0–9 at Easy, Normal and Hard, 36,000 ticks, passive player kept solvent) meets the year-5 floors of `rival-towns` / Rival viability with no margin on Normal and Hard. A per-year trace of the weakest rivals shows the same state in each: building cap reached, food 0 in every store, 4–14 empty houses, and a treasury growing by about $2,000 a year with nothing to spend it on.

The goal of #98 is a 10-seed minimum of at least the floor + 5 on every difficulty at year 5 (13, 25 and 35 residents), without making Easy rivals much stronger.

## Goals / Non-Goals

**Goals:**
- Year-5 minimum at least 13 on Easy, 25 on Normal and 35 on Hard over seeds 0–9.
- Easy rivals stay about as large as they are now.

**Non-Goals:**
- Changing the floors, the caps, the reserve or the market rules.
- Demolishing rival buildings.

## Decisions

### D1. Three farms for every two houses

A farm yields 1 food per 40 ticks, and every other tick in winter. A citizens' house of 6 eats 3 food per 100 ticks; a peasants' house of 4 eats 2. One farm per house feeds peasants but not citizens. The farm rule now applies while farms × 2 < houses × 3.

Alternative: two farms per house. In the sweep it raised the Normal minimum to 30, but Hard fell to 25, because the extra farms crowd houses out at the cap.

### D2. Hut limit once a town replants

The wood rule asks for a new hut whenever the rival's huts have fewer than 6 forest tiles left, and thinned huts never go away. Once a rival has a forester, which replants beside its huts, it builds no hut past 2 + houses / 2 huts, thinned ones included. The limit applies to the wood rule and to the script's hut steps alike, which are skipped at the limit. Before its first forester, nothing changes: a rival in its opening whose first huts are cut must still be able to get wood. With the limit applied from the start, one Normal rival lost its wood for good in the opening and ended year 5 with 14 residents.

### D3. A first warehouse, at the cap too

A rival whose town center has fewer than 4 units of room (the market rules' "full") and no warehouse built or under construction builds a warehouse before the threshold rules. The step waits while a site waits for materials, like the other non-hut steps, and may cost a market purchase of wood or planks like any step. It is the only step a rival takes at the building cap. The opening's own warehouse step is skipped once a warehouse stands, so a town never builds a second one. Many towns fill their town center only once they are at the cap, and with the cap blocking the warehouse the weakest Hard rival in the sweep stayed at 27 residents.

Alternative: count warehouses out of the building cap, like foresters. That gives every town one more building, not only the jammed ones.

## Evidence

The `rival-ai-viability` result (before) against this change (after), from the same sweep. The numbers come from an uncommitted harness that also logs buildings and stock per year; on `main` its residents match the committed `RIVAL_SWEEP=1` scenario test line for line. The `rival-sweep` workflow run of that test on this change (run 38763412083) reports the same "after" residents.

|                                  | Easy         | Normal       | Hard         |
| -------------------------------- | ------------ | ------------ | ------------ |
| Year-5 floor (+5 target)         | 8 (13)       | 20 (25)      | 30 (35)      |
| Year 5, minimum                  | 15 → 15      | 20 → 42      | 30 → 45      |
| Year 5, median                   | 20.5 → 24.5  | 35.5 → 53    | 43 → 62      |
| Year 15, minimum                 | 13 → 15      | 25 → 28      | 28 → 37      |
| Year 15, median                  | 19 → 21      | 37.5 → 50.5  | 42 → 62      |
| Rivals with a warehouse, year 15 | 2/10 → 10/10 | 0/20 → 20/20 | 0/30 → 30/30 |
| Lumberjack huts, year 15, median | 9.5 → 8.5    | 12.5 → 9     | 18 → 13      |

The "after" column includes the script skips for huts and warehouses that followed #105. Before them, the year-5 minimums were 15, 35 and 45, and the year-15 minimums 15, 35 and 46.

No rival has 0 residents in any year from year 3 on, and no treasury drops below $50 in either run.

Year-5 minimum on Normal and Hard for each rule and combination tried:

| Variant                               | Normal | Hard |
| ------------------------------------- | ------ | ---- |
| Before                                | 20     | 30   |
| D1 only                               | 27     | 25   |
| D1 with two farms per house           | 30     | 25   |
| D3 only                               | 20     | 32   |
| D1 and D3                             | 26     | 35   |
| D1 and D2, D2 applied from the start  | 14     | 30   |
| D1, D2 and D3, without D3 at the cap  | 31     | 27   |
| D1, D2 and D3                         | 35     | 45   |
| Hard building cap 80, no rule changes | —      | 32   |

The rules work together: D3 lets food reach the houses, D1 grows enough of it, and D2 frees the cap slots for the farms. Single runs are chaotic per seed, so only the combination clears every target.

## Risks / Trade-offs

- **Easy rivals grow a little.** The Easy median at year 5 rises from 20.5 to 22 and the minimum stays at 15. Easy is still the smallest by far, so the "outgrow every rival" goal stays easy there.
- **Hard rivals are larger.** The Hard median at year 5 rises from 43 to 62, so outgrowing every Hard rival takes longer. That is what Hard is for.
- **Year-15 tails move per seed.** After the script skips, the year-15 medians rose (Normal 49.5 → 50.5, Hard 58 → 62), while the weakest towns moved the other way (Normal 35 → 28, Hard 46 → 37). The plank pile was already there after #105: by year 15 the median town holds about 200 planks, which fill its one warehouse and can shut food out of the weakest towns. #112 tackles the surplus.
- **Margins are per seed.** A balance change elsewhere can still move single seeds by 10 residents or more. The weekly `rival-sweep` workflow catches that.

## Migration Plan

None: rival state is unchanged and saves load as before. Games in progress pick up the new rules on the rival's next turn.
