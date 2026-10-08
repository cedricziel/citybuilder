## Why

The game direction says culture is picked at the start of a game, alongside the age, and that each culture has its own buildings, goods and look. Today there is one implicit culture: the half-timbered Northern European town. Before ages and culture-specific content can land, the world needs to know its culture, the player needs to choose it, and the city needs to look like it.

## What Changes

- **Culture:** a new-game choice among four cultures: Northern European, Mediterranean, East Asian and Middle Eastern. The world stores it for the whole game.
- **New Game dialog:** a culture picker with a one-line description of each culture.
- **Look:** houses (all three tiers), the town center, the warehouse and the library are drawn in each culture's style, in the same procedural register:
  - **Northern European:** today's plaster, timber frame and steep tiled roofs.
  - **Mediterranean:** whitewashed walls, low terracotta hip roofs and a bell tower on the town center.
  - **East Asian:** timber pillars and pale walls under dark, wide-eaved roofs, with a pagoda-style town center.
  - **Middle Eastern:** sandstone walls, flat roofs with parapets, and domes on the town center and library.
  Other buildings keep their current look in every culture for now.
- **Tier names:** each culture names its three resident tiers (for example plebeians, citizens and patricians in the Mediterranean). The inspector uses them.
- **Saves:** a v5 → v6 migration makes existing saves Northern European.

Culture-specific goods, buildings and signature mechanics stay in `add-culture-content`.

## Capabilities

### New Capabilities

- `cultures`: the culture choice, its stored value and per-culture tier names.

### Modified Capabilities

- `persistence-save-load`: the v5 → v6 migration.
- `platform-shells`: the culture picker.
- `rendering-2_5d`: culture-specific building sprites with fallback.
- `sprite-style-catalog`: per-culture building entries.

## Impact

- **CityCore:** `Culture`, `World.culture`, `World.newGame(layout:seed:culture:)`, `HouseTier.displayName(in:)`, culture on `WorldSnapshot`.
- **CityPersistence:** save version 6 and its migration.
- **CityUI:** culture picker, inspector tier names.
- **CityRender2D:** culture-aware texture lookup.
- **Art:** 18 new procedural sprites (6 buildings × 3 cultures), a style table in the building kit, and dome and stacked-roof primitives.
