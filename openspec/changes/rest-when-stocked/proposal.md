## Why

Merchants don't hold (#223). A careful town reaches the Renaissance, then loses its merchants within a year. In years 8–10 it has 20 or more merchants in only 6% of turns.

A trace shows the cause is wood, not tools:
- six to nine sawmills turn every log into planks, and 100–180 planks pile up unused;
- so the charcoal burner, the smelter and the toolsmith all wait for their inputs;
- supply carriers serve producers in entity order, so nothing stops a sawmill while planks are plentiful.

A player hits the same trap. The only sign is "Waiting for wood" in each starved building's inspector.

Measured (careful scripted player, market on, 60 starts, to year 10):

| Variant | 20+ merchants at year 10 | Share of years 8–10 with 20+ | Renaissance, Normal median |
|---|---|---|---|
| Today | 8/60 | 0.06 | 6.5 years |
| Tools eaten at a quarter of the rate | 8/60 | 0.06 | 6.5 years |
| Producers rest at 40 of their output | 14/60 | 0.28 | 5.3 years |

## What Changes

- **Producers rest while the stores hold plenty.** A good can declare a rest level in its pack; the shipped goods made from inputs get 40.
  - While the owner's stores hold that much of everything a producer makes, nothing brings it inputs: no supply pull, and no direct hop from another producer.
  - The inputs then go to the buildings that need them.
- **It's visible and calm.** The inspector shows "Resting: stores hold plenty of planks" in place of a problem line, with no warning symbol. A resting building draws as idle, with no smoke and unlit, because it has an issue.
- **Research is retuned** so Normal stays at 6–8 years to the Renaissance. Resting speeds the climb up by about a year. The new costs are set by measurement in this change (design D3).

Out of scope:
- Food and luxury throughput: re-measured after this lands.
- The sustained-merchants gate: re-measured after this lands.
- The wool → cloth chain.

## Capabilities

### New Capabilities
- (none)

### Modified Capabilities
- `goods-and-production`: adds "Producers rest while the stores hold plenty".
- `warehouses-and-logistics`: "Buildings report why they are idle" gains the resting issue.
- `platform-shells`: "Inspector callout" shows resting as a calm line.
- `research` and `culture-content`: retuned costs, once measured (design D3).

## Impact

- **Game data:** an optional `restAt` on goods, set to 40 on planks, flour, bread, charcoal, iron, tools and the luxuries. GameDataGen learns the field.
- **CityCore:**
  - `World.isResting(_:)`, used by supply dispatch and by walkers' direct hops (#232).
  - `BuildingIssue.resting(Good)`.
- **CityUI:** the inspector's calm resting line.
- **Coordination:** walkers' #232 (direct hops) lands first. This change then merges main and gates both paths through one predicate.
- **Sweeps:** pacing with retention, first-hour solvency, and rival viability.
