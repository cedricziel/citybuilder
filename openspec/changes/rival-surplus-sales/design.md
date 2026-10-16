## Context

After `rival-viability-margin`, rivals clear the year-5 floors with margin, but by year 15 the median town holds about 200 planks and no wood. #112 asks for a year-15 minimum of at least floor + 5 on every difficulty (13, 25 and 35 residents), with year 5 unchanged.

On `main` after #108 the sweep (archipelago seeds 0–9, 36,000 ticks) already meets that bar, though thinly: the weakest towns at year 15 have 15, 28 and 37 residents. A trace of the weakest Normal town shows food production close to consumption at the building cap: 17 farms make about 40 food per 100 ticks against 33 eaten, so the store sits near 0 and its houses cannot grow. That town has a port and 200 units of free room, so the plank pile is not what blocks its food. In towns whose stores do fill, the pile leaves the farms nowhere to deliver.

## Goals / Non-Goals

**Goals:**
- Keep the plank surplus out of crowded stores.
- Year-15 minimum at least floor + 5 on every difficulty, with year 5 no worse.

**Non-Goals:**
- Raising the weakest Normal town's food production at the building cap; no rule tried below did that without costing another difficulty.

## Decisions

### D1. Sell surplus planks and wood when the stores are crowded

A rival whose goods buffers together have fewer than 40 units of room sells planks, then wood, above 60 units, one good per turn, within its seasonal sell limit of 20 per good. The 40-unit gate keeps young towns, whose only store is the 40-unit town center, out of the rule until they are crowded, so the early game does not change.

### D2. Alternatives tried

Year-5 and year-15 minimums, Easy / Normal / Hard, from the same sweep:

| Variant                                              | Year 5       | Year 15      |
| ---------------------------------------------------- | ------------ | ------------ |
| `main` after #108                                    | 15 / 42 / 45 | 15 / 28 / 37 |
| Sell above 60, no gate                               | 12 / 43 / 50 | 13 / 41 / 57 |
| Sell above 60, under 40 units of room (D1)           | 15 / 44 / 46 | 15 / 28 / 42 |
| Sell above 40, under 40 units of room                | 15 / 44 / 46 | 15 / 28 / 42 |
| Sell above 60, under 80 units of room                | 15 / 38 / 46 | 15 / 28 / 42 |
| Skip sawmill steps while planks are 40 or more       | 15 / 42 / 45 | 15 / 28 / 37 |
| Skip house steps while a house starves               | 18 / 42 / 29 | 12 / 36 / 34 |
| Skip house steps while a house starves, near the cap | 16 / 42 / 45 | 15 / 28 / 37 |

- Selling without a gate fixes the late tails but changes the early game: the weakest Easy town falls to 12 at year 5, below its target of 13.
- Skipping sawmill steps changes nothing. The sawmills are built before planks pile up, and towns at the building cap take no script steps.
- Skipping house steps while a house starves trades one difficulty for another.

## Evidence

See D2. Final numbers are in the PR, from the committed `RIVAL_SWEEP=1` scenario test.

## Risks / Trade-offs

- **The weakest Normal town is food-bound at the cap.** Its year-15 minimum stays at 28, above the target of 25 but not by much. Raising it needs more food per building slot, which is a balance change of its own.

## Migration Plan

None: rival state is unchanged.
