## Why

The longest chain today is two steps (wood → planks), and "food" is a single generic good. The direction calls for Anno-depth chains of six or more steps with multiple inputs, and population tiers now exist to demand them. The island's large mountain core is also unused land.

## What Changes

- **Grain and flour replace generic food as the bread input:** the farm keeps producing food for everyday needs; a new **grain farm** grows grain, a **windmill** grinds grain into flour, and the **bakery** now bakes bread from flour instead of food.
- **Iron and tools, a multi-input chain:**
  - **mine** (must stand on at least 2 mountain tiles) extracts ore;
  - **charcoal burner** turns wood into charcoal;
  - **smelter** turns ore + charcoal into iron;
  - **toolsmith** turns iron + planks into tools.
  The longest chain is now forest → wood → charcoal → iron → tools → merchant house, with ore and planks feeding in from two more chains (six production buildings).
- **Merchants need tools** as well as food, planks and bread, consuming 1 tool per 8 residents (rounded up).
- **New goods:** grain, flour, ore, charcoal, iron, tools, each with an icon.
- **Placement rule:** a building can declare a terrain requirement; the mine is rejected with "Needs mountain ground" unless at least 2 of its tiles are mountain.
- **Art:** grain farm, windmill (with turning-sail frames), mine, charcoal burner, smelter and toolsmith in the procedural register, plus the six icons.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `goods-and-production`: six new goods, five new recipes, the bakery's input changes to flour.
- `buildings-and-construction`: six new buildings and the terrain-requirement placement rule.
- `population-and-needs`: merchants need tools.
- `platform-shells`: the rejection message for missing mountain ground.

## Impact

- **CityCore:** new `Good` and `BuildingKind` cases, recipes, specs, `PlacementRejection.needsTerrain`, and a merchant need. Saves stay compatible (only new enum cases).
- **CityRender2D / CityUI:** animation entries, palette labels, rejection text.
- **Art:** six buildings and six icons, all procedural.
