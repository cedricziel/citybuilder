## Why

Every house is the same: it fills to 4 residents and stops. Nothing asks for more than food and planks, so there's no reason to build longer chains and no visible sense of the town getting richer. The game direction (see `openspec/explorations/game-direction-pile.md`) puts population tiers next: richer residents demand new goods, and that demand is what pulls deeper production chains and, later, the drift through the ages.

## What Changes

- **Three tiers per house:** peasants, citizens, merchants. Each tier has a resident capacity (4, 6, 8), a list of needs, and a tax rate per resident (1, 2, 4).
  - Peasants need food.
  - Citizens need food and planks.
  - Merchants need food, planks and bread.
- **Advancement:** a full house whose next-tier needs are all met for 120 ticks moves up a tier. A house whose current-tier needs go unmet for 120 ticks moves down a tier, and its residents are clamped to the lower capacity.
- **BREAKING (needs):** peasants no longer need planks; only citizens and up consume them. Merchants also eat 1 bread per 4 residents (rounded up) each consumption interval.
- **Bakery:** a new 2×2 building ($90, 2 wood + 2 planks) turns 2 food into 1 bread every 50 ticks, supplied by carriers like the sawmill. Bread is a new good with an icon.
- **Houses look their tier:** each tier has its own house sprite (`building-house`, `building-house-tier2`, `building-house-tier3`), drawn by the procedural kit.
- **Inspector:** shows the tier, residents against capacity, and each need's status for the house's current tier.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `population-and-needs`: tiers, per-tier capacity, needs, advancement and tax; consumption depends on tier.
- `goods-and-production`: bread and the bakery recipe.
- `buildings-and-construction`: the bakery building.
- `rendering-2_5d`: houses render the sprite for their tier.

## Impact

- **CityCore:** `HousePopulation` gains a `tier`, decoded as peasants when an older save has none. New `Good.bread`, `BuildingKind.bakery`, and tier tables. Stays Foundation-only.
- **CityRender2D:** the snapshot carries each house's tier, and the sprite spec includes it.
- **CityUI:** inspector lines, a bread icon in the HUD, and the bakery in the palette.
- **Art:** tier-2 and tier-3 houses, the bakery, and a bread icon, all procedural.
- **CityPersistence:** no format change (the new field is optional on decode).
