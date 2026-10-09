# Pack format reference (draft)

A pack is one YAML document: optional `defaults` (anchors only, ignored except where merged with `<<:`), then `items`, an ordered list. Every item has `kind` and `id` (kebab-case). Keys written on an item win over merged keys.

## Kinds and fields

| Kind | Required | Optional |
|---|---|---|
| `Good` | `id`, `name`, `unit` (plural stack noun), `basePrice` (int > 0) | |
| `Building` | `id`, `footprint` `[w, h]`, `cost` (int ≥ 0) | `name` (palette label, default: id title-cased), `storage` (stockpile capacity; omit for none), `upkeep` (int, default 0), `buildTicks` (int > 0, default 30), `materials` `{good: int}`, `recipe`, `effect` (`code`), `unlockedBy` (tech), `obsoletedBy` (tech), `culture` (culture id: only that culture may build it), `placement`, `legacyIds` [string] |
| `Culture` | `id`, `name`, `blurb`, `tiers` `{peasants, citizens, merchants}` (display names), `luxury` `{raw, good, garden, producer}`, `signature` (building), `residentNames` [string] | |
| `Tech` | `id`, `cost` (knowledge, int > 0), `age` (age from which it can be researched) | `name` (default: id title-cased), `prerequisites` [tech], `era` (age this tech opens), `eraGate` `{tier, residents}` (required when `era` is set) |
| `Age` | `id`, `startYear` (astronomical: −499 = 500 BC), `blurb`, `signature` (building), `rivalResidents` (residents a rival needs to enter this age) | `name` |

`recipe`: `{ inputs: {good: int}, outputs: {good: int}, cycleTicks: int > 0 }`. `inputs` is optional. `outputs` must name at least one good unless the building also sets `effect: code`, in which case `outputs` may be left out.

`effect: code`: the building's behaviour is written in Swift (houses, storage, roads, town center, library, port, shipyard, monument, signature buildings). A building with no producing recipe and no `effect` is rejected as inert. A new code-effect building compiles but does nothing until its Swift behaviour is written.

`placement`: either `{ shore: { minLand: int, minWater: int } }` or `{ terrain: { type: grass|forest|beach|water|mountain, minTiles: int } }`.

Tiers: `peasants`, `citizens`, `merchants`. Merchants additionally need their culture's luxury good.

## Rules

- References may point to items in any pack; packs never edit each other.
- A culture's `luxury.garden` and `luxury.producer` must be buildings with `culture:` set to that culture; the garden outputs `luxury.raw`, the producer turns `raw` into `good`.
- Luxury gardens and producers are unlocked by `cultivation`.
- Ids are unique per kind across all packs.
- The sim runs at 10 ticks per second.
- Every building, culture and age needs sprite catalog entries; the existing `SpritesStyleCatalogTests` lists what it expects.
- `eraGate.tier` and the culture `tiers` keys must be `peasants`, `citizens` or `merchants`.
- Every good needs a consumer: a recipe input, a material, a culture luxury, or a house tier need. Tier needs are still in Swift (`HouseTier.needs`: food, planks, bread, tools), so a new consumer good also needs that follow-up change.

## Existing content you can reference (from core and ages packs)

- Goods: wood, planks, food, bread, grain, flour, ore, charcoal, iron, tools (+ per culture: hops, beer, grapes, wine, tea-leaves, tea, coffee-cherries, coffee)
- Buildings: house, warehouse, road, lumberjack-hut, sawmill, farm, bakery, grain-farm, windmill, quern-house, mine, charcoal-burner, smelter, toolsmith, library, town-center, port, shipyard, monument, guild-hall, gallery, steam-engine, power-plant
- Techs: scholarship, milling, mining, metallurgy, seafaring, cultivation, feudal-order, printing-press, steam-power, electricity
- Ages: antiquity, medieval, renaissance, industrial, modern
- Cultures: northern-european, mediterranean, east-asian, middle-eastern

## Balance anchors (today's values)

- Raw goods 3–5, processed 6–14, tools 30, luxuries 16.
- Gardens: cost 60, 25 build ticks, output 1 raw per 40 ticks. Luxury producers: cost 120, 2 raw → 1 luxury per 50 ticks.
- Culture signatures: 3×3, cost 160–220, upkeep 1–2, 35–40 build ticks.
- Era techs cost 150 / 250 / 400 / 600; regular techs 30–80.
