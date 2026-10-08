## Why

Every building is available from the first minute, so there is no sense of a society developing, and the game direction's "gradual drift" needs a supply side: knowledge that unlocks new buildings one at a time. This change adds that mechanism inside the current setting; later ages will extend the same tech tree.

## What Changes

- **Knowledge:** a city-wide total that accumulates every tick. Each operational **library** adds 1 point every 10 ticks, and each citizen or merchant resident adds a little more (1 point per 100 ticks per resident).
- **Tech tree:** five techs with costs and prerequisites:
  - **Milling** (40): grain farm, windmill, bakery.
  - **Mining** (40): mine, charcoal burner.
  - **Metallurgy** (80, needs Mining): smelter, toolsmith.
  - **Seafaring** (60): port, shipyard.
  - **Scholarship** (30): library. Granted at the start so research can begin.
- **Choosing research:** the player picks one tech whose prerequisites are met; knowledge flows into it until it completes, then the next pick starts from zero. Unspent knowledge with no tech chosen is kept.
- **Locked buildings:** placing a building whose tech is not researched is rejected with "Needs <Tech> research", and the palette shows it greyed with a lock.
- **Research panel:** a HUD button opens a sheet listing techs with cost, progress, prerequisites and unlocks, where the player picks the current research.
- **Library:** a new 2×2 building ($100, 2 wood + 4 planks), drawn in the procedural register.
- **Saves:** a v3 → v4 migration gives existing saves every tech, so nobody loses buildings they had.

## Capabilities

### New Capabilities

- `research`: knowledge, the tech tree, choosing research and locked buildings.

### Modified Capabilities

- `buildings-and-construction`: the library, and the tech-lock placement rule.
- `persistence-save-load`: the v3 → v4 migration.
- `platform-shells`: the research panel and locked palette entries.

## Impact

- **CityCore:** `Tech`, `ResearchState` on `World`, a `.chooseResearch` command, `PlacementRejection.locked(Tech)`, `BuildingKind.library`.
- **CityPersistence:** save version 4 and its migration.
- **CityUI:** research button, sheet and view model; palette lock state.
- **Art:** library sprites.
