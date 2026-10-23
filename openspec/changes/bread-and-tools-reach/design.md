## Context

The bread chain needs no research: grain farm, then quern house (or windmill after Milling), then bakery. The tools chain needs the Medieval age: Mining unlocks the mine and charcoal burner, and Metallurgy unlocks the smelter and toolsmith. Every link has unit tests (`ChainTests`). A merchants' house needs food, planks, bread and tools, and the market sells neither bread nor tools.

A scan of new games (seeds 0–49, Normal) checked every town center's island for a mine site:

| Island                     | Without a mine site                                          |
| -------------------------- | ------------------------------------------------------------ |
| Player's home island       | none                                                         |
| Other player start islands | 11 archipelago starts: island 1 on seeds 5, 12, 24, 43; island 4 on seeds 2, 4, 13, 17, 41, 42, 47 |
| Rival home islands         | seed 17 rival 1, seed 30 rival 2                              |
| Single-island starts       | none                                                         |

Those islands have mountains, but never two in one 2×2 square. A first scan read the lowest-ID player town center as the home island, which it isn't, and so overstated the gap: no home island in these seeds lacks a mine site.

## Goals / Non-Goals

**Goals:**
- Every town center's island can hold a mine, so a town that grows from any start island can make tools.
- A player can see what the next house tier needs and what unlocks a locked building.

**Non-Goals:**
- Scripted bots that build the mid-game chains, market changes, or new building kinds.

## Decisions

### D1. Raise one tile beside a mountain

Like the starter grove, the fix changes terrain after each town center is placed, before rivals take their islands, and touches no island that is already fine. Every island in the scan that lacks a site has mountains, so a neighbour of the mountain nearest the town center almost always works. Grass is tried before forest, so the trees a hut site counts on stay. The candidate order is fixed (grass first, then distance, `y`, `x`, and right, lower, left, upper), so generation stays deterministic. A site must stay clear of the town center's road ring, because the starter roads take those tiles after the raise. "Mine site" means the real placement rule for a mine once Mining is researched, so the guarantee can't drift from it.

Alternatives: selling tools at the market changes the economy and the market spec. Rejecting start sites without a mine site would move the town center, which the fair-start rules already constrain tightly.

### D2. Next-tier needs as one key line

"Next: Merchants need bread, tools" names only the goods the next tier adds, so a citizens' house doesn't repeat food and planks. A top-tier house has no such line. It is a text line in the existing callout, so the layout is unchanged.

### D3. "Needs <Tech>" in place of the cost

The locked drawer tile already dims and shows a lock; its price line becomes "Needs Mining". That is the same message a rejected placement shows, in shorter form, and the same space, so the layout is unchanged.

## Risks / Trade-offs

- **The raise changes the island under a start.** The raised tile lies outside the town center's start area and is never occupied, so the start area's grass and mountain counts, which the fair-start rules check, are unchanged. The fair-start tests run again to confirm it.
- **Determinism:** starts that needed a raise play differently. The rival sweep for seeds 0–9 and for seeds 17 and 30, whose rival islands are raised, gives identical results with and without the raise: rivals don't build mines, and the raised tile stays off their plans.
- **The gap was smaller than first thought.** Home islands already hold a mine site, so the change mainly helps towns that grow from another start island.

## Migration Plan

None: only new games change. Saves keep their terrain.
