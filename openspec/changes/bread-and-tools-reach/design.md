## Context

The bread chain needs no research: grain farm, then quern house (or windmill after Milling), then bakery. The tools chain needs the Medieval age: Mining unlocks the mine and charcoal burner, and Metallurgy unlocks the smelter and toolsmith. Every link has unit tests (`ChainTests`). A merchants' house needs food, planks, bread and tools, and the market sells neither bread nor tools.

A scan of new games (seeds 0–49, Normal) found:

| Layout        | Home islands without a mine site | Mountain tiles on those islands |
| ------------- | -------------------------------- | ------------------------------- |
| Single island | 0 / 50                           | —                               |
| Archipelago   | 4 / 50 (seeds 5, 12, 24, 43)     | 27–39, never two in one 2×2     |

## Goals / Non-Goals

**Goals:**
- Every home island can hold a mine.
- A player can see what the next house tier needs and what unlocks a locked building.

**Non-Goals:**
- Scripted bots that build the mid-game chains, market changes, or new building kinds.

## Decisions

### D1. Raise one tile beside a mountain

Like the starter grove, the fix changes terrain after the town center is placed and touches no island that is already fine. Every home island in the scan has at least 27 mountain tiles, so a grass or forest neighbour of the mountain nearest the town center almost always works. The candidate order is fixed (distance, then `y`, then `x`, then right, lower, left, upper), so generation stays deterministic. "Mine site" means the real placement rule for a mine once Mining is researched, so the guarantee can't drift from it.

Alternatives: selling tools at the market changes the economy and the market spec. Rejecting start sites without a mine site would move the town center, which the fair-start rules already constrain tightly.

### D2. Next-tier needs as one key line

"Next: Merchants need bread, tools" names only the goods the next tier adds, so a citizens' house doesn't repeat food and planks. A top-tier house has no such line. It is a text line in the existing callout, so the layout is unchanged.

### D3. "Needs <Tech>" in place of the cost

The locked drawer tile already dims and shows a lock; its price line becomes "Needs Mining". That is the same message a rejected placement shows, in shorter form, and the same space, so the layout is unchanged.

## Risks / Trade-offs

- **The raise changes the island under a start.** The raised tile lies outside the town center's start area and is never occupied, so the start area's grass and mountain counts, which the fair-start rules check, are unchanged. The fair-start tests run again to confirm it.
- **Determinism:** starts that needed a raise play differently, including any rival on that island, so the rival sweep runs again.

## Migration Plan

None: only new games change. Saves keep their terrain.
