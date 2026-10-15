## Context

See proposal.md (Why). The rival AI (`Systems/RivalSystem.swift`, spec `rival-towns`) takes one step per turn: every 80 ticks on Easy, 50 on Normal and 30 on Hard. A step is the first threshold rule that applies (food → farm, planks → sawmill once past the opening, wood → lumberjack hut, then forester), or else the next script step. A step is issued only when the treasury covers building cost + road cost + $50. A rival pays upkeep and earns tax like the player, but it never goes bankrupt; in debt it just waits. Caps: 30 houses, and no step at 50 non-road buildings. The starting treasury is $600, $1,000 or $1,400, with the difficulty's starter stock (Easy 10 wood, 8 planks, 4 food; Normal 6/5/2; Hard 4/3/1). A house costs $50 and 4 planks, a sawmill $120 and 1 plank (+ $2 upkeep per 50 ticks), and each road tile $5. The first building opens a 20-tile ring, and each new block opens more.

### Evidence

A scratch harness (not committed) ran archipelago seeds 0–9 at each difficulty for 36,000 ticks (15 years) on `main` at fa8a5dd: 10 rivals on Easy, 20 on Normal, 30 on Hard. The player was passive and its balance was topped up, because a game over stops all tax and upkeep, the rivals' included. The numbers are also posted on issue #69.

| Baseline | Easy | Normal | Hard |
|---|---|---|---|
| Rivals at 0 residents, year 15 | 10/10 | 6/20 | 12/30 |
| Residents year 3, median (range) | 0 | 27 (0–51) | 14 (0–43) |
| Residents year 15 | 0 | 25.5 (0–49) | 21 (0–48) |
| Treasury year 15 | −$1,334 | $23,967 (−$1,344…$77,205) | $11,779 (−$1,329…$50,899) |
| Top tier year 15 | none | citizens 14, none 6 | citizens 14, peasants 4, none 12 |

What the rows show:

- **Dead rivals spend before they earn.** An Easy rival's opening (48 road tiles, a hut, a sawmill and a farm) leaves $10 at the end of year 1. A house needs $50 + roads + $50. Then the sawmill's upkeep ($96 a year) runs the treasury down $96 a year to −$1,334, and the rival never takes another step. A dead Hard rival (seed 4, rival 1) had built 5 huts and 5 foresters by the end of year 1, but only 1 farm and 2 houses. It had 1 resident, $53, 0 food, and 40 planks filling its town center. Those planks would sell for $160 at the market.
- **Living rivals hit the building cap by year 3.** All 32 sit at exactly 50 non-road buildings: about 16 houses, 12 farms, 8 lumberjack huts and 8 foresters. Median residents per year: 10, 21, 32, 30, 30, …, 27.
- **Food is short.** Every living rival ends with 0 food and a median of 5 empty houses. The farm rule keeps 4 farms per 5 houses.
- **Money piles up.** Living treasuries reach $7,800–$77,200 with nothing to spend on. No rival reaches merchants, because the rival building list has no citizen or merchant chain.

Two counterfactuals were run with scratch edits to `RivalSystem.swift`:

| Variant | Rivals at 0 residents | Easy / Normal / Hard residents year 15 |
|---|---|---|
| A: opening with houses before the sawmill; forester only after the opening and with ≥ 4 houses; non-house steps keep $150 until 3 houses | 0/60 | 8 / 4 / 33.5 |
| B: original opening; same forester gate and reserve | 8/60 | 4 / 24 / 23.5 |

Both show the second dead end. Once planks reach 0 without a sawmill, the rival can build neither a house (4 planks) nor a sawmill (1 plank). It then sits for 15 years with $1,000–$4,500 and 20–30 food. In A, the house steps used up the starter planks before the sawmill step. In B, the reserve held back the sawmill while houses used up the planks.

### M1 result

The same 15-year sweep run on the M1 branch, with the baseline in brackets:

|                                | Easy         | Normal      | Hard         |
| ------------------------------ | ------------ | ----------- | ------------ |
| Rivals at 0 residents, year 15 | 3/10 (10/10) | 1/20 (6/20) | 5/30 (12/30) |
| Residents year 3, median       | 9 (0)        | 35.5 (27)   | 21.5 (14)    |
| Residents year 5, median       | 22.5 (0)     | 35 (25)     | 21.5 (20)    |
| Residents year 15, median      | 19 (0)       | 35.5 (25.5) | 24 (21)      |
| Rivals ever in debt            | 3 (10)       | 1 (6)       | 5 (12)       |
| Citizens reached by year 15    | 6 (0)        | 19 (14)     | 21 (14)      |

Rivals at 0 residents fall from 28 to 9 of 60. All 9 end the same way:

- the town center is full, with 40 planks;
- wood and food are at 0;
- the rival cannot pay for a farm.

The sawmill turns all the wood into planks that nothing uses or sells. M2's market trades target exactly this: selling surplus when short of money, and buying food.

Two dead ends were tried and rejected during M1:

- **A storage threshold rule** (a warehouse when the buffers are nearly full) made Easy worse: 10 of 10 rivals at 0 residents.
- **The first version of the sawmill rule** (no hut condition, a sawmill that still cost materials) left 13 rivals at 0, 7 of them on Hard.

M1 also found and fixed a placement bug. `applyPlace` read a building's material cost after inserting it, so a rival's first sawmill was charged a plank it did not have, and the site waited forever.

### M2 result

The same sweep with rival market trades on top of M1, M1 values in brackets:

|                                    | Easy         | Normal      | Hard        |
| ---------------------------------- | ------------ | ----------- | ----------- |
| Rivals at 0 residents, year 15     | 0/10 (3/10)  | 0/20 (1/20) | 0/30 (5/30) |
| Rivals ever in debt                | 0 (3)        | 0 (1)       | 0 (5)       |
| Residents year 3, median           | 13 (9)       | 36 (35.5)   | 33 (21.5)   |
| Residents year 5, median | 28 (22.5) | 34 (35) | 32 (21.5) |
| Residents year 5, minimum | 15 (0) | 23 (0) | 21 (0) |
| Residents year 15, median | 25.5 (19) | 35 (35.5) | 33 (24) |
| Residents year 15, minimum | 18 (0) | 27 (0) | 20 (0) |
| Citizens reached by year 15 | 10 (6) | 20 (19) | 30 (21) |

Every rival survives, none goes into debt, and all reach the citizen tier. D7's year-5 floors hold on Easy (8) and Normal (20). Hard's floor of 30 does not: the median is 32, but the weakest Hard rival has 21. That is M3's input.

Three things M2 found and changed before this result:

- **Unblock purchases come with the step.** A purchase made on its own turn lost the race to the sawmill's supply carriers: a farm's 2 wood went into planks before the farm was placed, and the rival bought 2 wood again every turn for years. That gave Easy a median of 2 residents at year 5. The purchase now goes into the same command batch as the step's roads and building, ahead of them.
- **A starving town clears a full store.** One Easy rival hit the building cap with its town center full of 40 planks. The farms then had nowhere to put food, and the town emptied. A rival whose town center has under 4 units of room and under 4 food now sells surplus as if in debt.
- **No purchase without room.** A purchase into a full town center fills nothing and, with no fill recorded, repeats every turn. That is the rival side of #70. Rivals buy only what fits.

### M3 result

The same sweep with the difficulty caps of D6 on top of M2, with M2 in brackets:

|                                | Easy        | Normal      | Hard        |
| ------------------------------ | ----------- | ----------- | ----------- |
| Rivals at 0 residents, year 15 | 0/10 (0/10) | 0/20 (0/20) | 0/30 (0/30) |
| Rivals ever in debt            | 0 (0)       | 0 (0)       | 0 (0)       |
| Residents year 5, median       | 20.5 (28)   | 35.5 (34)   | 43 (32)     |
| Residents year 5, minimum      | 15 (15)     | 20 (23)     | 30 (21)     |
| Residents year 15, median      | 19 (25.5)   | 37.5 (35)   | 42 (33)     |
| Houses at year 15, median      | 9.5         | 15          | 21          |

D7's year-5 floors hold on every seed: Easy 8, Normal 20 and Hard 30. Normal's minimum of 20 and Hard's of 30 sit exactly on their floors, so the caps are not tuned further. Difficulty now sets a rival's size: Hard rivals end around 42 residents and Easy rivals around 19. Hard rivals reach the Renaissance in 29 of 30 games, and one reaches the Industrial age.

Other M3 checks:

- **Tick budget.** With Hard's 64-building cap, the "replayed rival game" tick budget test passes in isolation.
- **Player playtest bot** (archipelago seed 7, the `add-forestry` harness, not committed). The bot reaches 23 residents by year 5 and 62 by year 10. The two rivals hold 30–43 residents from year 3 on. The bot first outgrows both between years 5 and 10, so "outgrow every rival" is reachable but no longer free.

## Goals / Non-Goals

**Goals:**
- No rival is left without residents, and no rival sits in debt for long, on any seed or difficulty.
- Rivals keep growing for several years instead of stopping at the building cap by year 3.
- Difficulty decides how strong a rival is, not whether it survives.

**Non-Goals:**
- New building kinds for rivals (bakery, toolmaker, luxury chains), so the merchant tier stays out of reach. That is the next step once rivals survive (see #71 for the player's side).
- Something to spend a large rival treasury on.
- Rival ports, offers and trade with the player (`rival-trade` unchanged).
- AI personalities or per-culture build orders.

## Decisions

### D1 — A house-first reserve, with the needed sawmill exempt

Until a rival has 3 houses with residents, a step needs $150 on top of cost, roads and the $50 margin, with three exemptions:

- houses, which bring income;
- farms, which bring food;
- a sawmill when the rival has none and its planks have fallen below a house's 4.

The sawmill exemption covers the plank dead end that B shows when a reserve holds the sawmill back.

M1 found that exempting every first sawmill was not enough. An Easy rival's opening hut opened 34 road tiles ($250 with the hut). The exempt sawmill then took $190 with its roads, and the farm $60. That left $96, and the next house needed $50 + roads + $50, so the rival still spiralled into debt. With the narrower exemption, an Easy rival that still holds 8 starter planks keeps its reserve: it builds a farm and a house first, then the sawmill. It has 6 residents in its first year and about 12 in its second.

- **Alternative — reorder the opening (variant A).** Rejected on its own: it removed the deaths but caused the plank dead end on Easy and Normal (4–8 residents for 15 years).
- **Alternative — waive rival upkeep until the first tax.** Rejected: it hides the problem, and a rival that spends its purse on roads still cannot afford houses.

### D2 — Sawmill first when planks are short

A rival with no sawmill (operational or under construction), at least one lumberjack hut, and fewer planks in stock than a house needs takes a sawmill step before any other step that uses planks. A rival's first sawmill costs no materials, like its huts and foresters.

M1 found two things the first version of this rule missed:

- **Residents eat planks.** A town at 4 planks with one occupied house was at 0 planks a few hundred ticks later, before it could pay for the sawmill. A sawmill that needed 1 plank could then never be built, and the town stayed at 4 residents for 15 years with money and food to spare. A free first sawmill removes that dead end for good, so it no longer waits for M2's market.
- **The rule should wait for a hut.** On Hard, the starter 3 planks fired it before the first hut, and the sawmill then took the opening's wood. Hard rivals at 0 residents rose from 12 to 13 in the sweep. With the hut condition, the count fell to 7.

### D3 — Foresters wait for the town

The forester rule applies only once the opening is complete and the rival has at least 4 houses. Foresters then still follow huts one to one, as `add-forestry` designed. A starter grove holds 32 trees, so a hut does not need a forester in its first years.

- **Alternative — drop the rule for rivals.** Rejected: rivals that thin their forest would lose wood for good, which is the soft-lock `add-forestry` fixed.

### D4 — One farm per house

The food rule becomes: food below 4 and fewer farms than houses → farm. The old ratio of 4 farms per 5 houses left every living town at 0 food with empty houses.

### D5 — Rivals trade at their own market, as a safety valve

On its turn, before threshold rules, a rival trades at its own town center's market (`add-town-market`) when one of these applies. A trade takes the turn, in this order:

1. **Unblock.** If the next step waits only for wood or planks and the treasury covers the purchase plus the step plus the margin, buy the shortfall.
2. **Pay debts.** If the treasury is below $150, sell stock above 12 units, planks first, then wood, then food.
3. **Feed.** If food is below 4, a rival house is short of food and the treasury is at least $300, buy up to 5 food.

Prices are the player's market prices. Seasonal limits (10 bought, 20 sold per good) are counted per rival and reset with the season like the player's. Rival trades go through the command queue as a new rival market command applied at the next tick boundary. They emit no player-facing event, and they never touch the player's counts or balance.

This reverses `add-town-market`'s "Rivals stay off the market". That change kept rivals off so the market would not become a rival money pump. Here a rival only sells when short of money and buys at 150%, so the market stays the worst channel and is never a profit source. The counterfactuals show the two dead ends it removes: a rival with planks and no money, and a rival with money and no planks.

- **Alternative — give rivals free materials for houses and sawmills.** Rejected: it is invisible to the player and breaks the "rivals play by the same economy" rule `rival-towns` set up.

### D6 — Caps scaled by difficulty, foresters and roads not counted

| | Easy | Normal | Hard |
|---|---|---|---|
| House cap | 16 | 24 | 32 |
| Building cap (excluding roads and foresters) | 32 | 48 | 64 |

The old cap counted foresters, which took 8 of 50 slots in every living town. The building cap counts houses too. These numbers set how big a rival gets; the turn interval and starting treasury still set how fast. They are starting values for M3 to tune against the targets in D7.

### D7 — A viability requirement measured by sweep

The `rival-towns` spec gains targets checked by test:
- No rival has 0 residents after the end of year 2.
- No rival's treasury stays below 0 for 2,400 consecutive ticks.
- By the end of year 5, every rival has at least 8 residents on Easy, 20 on Normal and 30 on Hard.

The scenario test is the full sweep: seeds 0–9 at each difficulty over 36,000 ticks, checking the three conditions above, with the residents floor read at the end of year 5. It takes minutes even in a release build, so it runs only with `RIVAL_SWEEP=1`, in a separate weekly `rival-sweep` workflow (also started by hand) that is not a required check and not part of `ci-ok`, and at each milestone's end. It prints one line per rival, and those lines are the evidence recorded here. Every CI run checks a lighter test instead: seed 0 at each difficulty over 3 years (7,200 ticks), with no rival empty on any tick after year 2 and none in debt for a year. That takes about a minute in the debug suite; the earlier 12,000-tick default took several.

### D8 — Determinism and CityCore

Rival decisions stay pure functions of world state. They draw no RNG and iterate no `Dictionary` (buildings by ID, goods in catalog order). Market prices and limits are integers. The rival market command is applied in queue order like `rivalPlace`. Every milestone changes the `DeterminismFixture` world and regenerates the `game-data-codegen` baseline on purpose, as `fair-start-sites` did. CityCore stays Foundation-only.

## Risks / Trade-offs

- [Rivals grow past the player too easily on Hard] → D7 sets floors, not ceilings, and the Island Rivalry scenario goal stays reachable. M3 re-runs the player playtest bot next to the rivals and records both.
- [Rival market buys fail when the town center is full (#70)] → Partial fills are normal. A rival in the "unblock" case is short of a good, so its town center is rarely full of it. #70's fix applies to rivals too.
- [The tick budget with bigger rival towns] → After the `fair-start-sites` perf fix, the 36,000-tick fixture runs in 24 s in a release build. M3 checks the "replayed rival game" tick budget with Hard's 64-building cap.
- [Money still piles up in big towns] → Accepted for now (non-goal). Standings show rival wealth.
- [Overlap with forestry work in `RivalSystem.swift`] → Rebase on any open forestry rival PR before starting M1.

## Migration Plan

Rival AI state gains per-rival market counts, which are optional in saves (zero when missing). Existing saves keep their rivals and play on under the new rules from the next turn.
