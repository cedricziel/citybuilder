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
- `spawnSupplyCarriers` skips a resting consumer.
- Walkers' #232 direct hops (producer → producer) skip a resting target through the same predicate. #232 lands first; this change merges main and adds the check there.
- The sum over the owner's stores runs once per producer per supply pass, which is cheap next to the path search.

### D3. Research retune

Resting brings the Renaissance about a year sooner on Normal (6.5 → 5.3 years with research ×10). The medieval tech costs are raised again so the Normal median stays inside 6–8 years and Easy stays clearly faster than Hard. The sweep picks the factor, and the `research` and `culture-content` deltas record it before the packs change.

### D4. Visible and idle

- `BuildingIssue.resting(Good)` is checked after the route to storage and before missing inputs, since a resting producer is also short of inputs.
- The inspector shows it as "Resting: stores hold plenty of planks": no warning symbol and no "Problem:" prefix.
- Rendering already treats a building with any issue as idle: no chimney smoke, no window glow, and no working animation.
