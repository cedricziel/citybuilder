## Why

The game direction ends its roadmap with AI-run towns competing for islands and trade. Today an archipelago game is solo: the player gets a town center on every island and nobody else builds anything. Rival towns give the archipelago a reason to exist and give the sandbox a yardstick ("am I doing well?"). This change adds the rivals themselves. Trading with them follows in `add-rival-trade`.

## What Changes

- **Rivals in archipelago games:** a new archipelago game gets rival towns by difficulty: 1 on Easy, 2 on Normal, 3 on Hard. A "Rival towns" toggle in the New Game dialog (default on) turns them off. Single-island games never have rivals.
- **Which islands:** the player's home island is the island under the map center (the large central island). Rivals take the other islands largest first; any island left over stays the player's, with its town center, as today.
- **Identity:** each rival has a name (its island's name), a colour (crimson, azure, emerald), a culture (different from the player's, taken in catalog order), its own treasury and its own age.
- **Ownership:** buildings and ships have an owner: the player or a rival. An island belongs to the rival seated on it, otherwise to the player. Placing on another owner's island is rejected ("Ravenshore's island"), and the player can't demolish rival buildings or clear their forests.
- **Rival AI:** each rival runs a small rule-based builder inside the simulation. Every few ticks (80 / 50 / 30 by difficulty) it picks one step from a fixed build order, overridden by stock thresholds (low food → farm, low planks → sawmill, low wood → lumberjack), finds a slot on a road grid around its town center and issues the same `place` path the player uses, through the command queue. It uses no randomness, so saves and replays stay deterministic.
- **Rival economy:** rival houses pay tax into the rival's treasury and rival buildings charge upkeep to it. Rivals never go bankrupt; a rival without money waits. The player's money, population, goals, events and research only count the player's own buildings.
- **Rival ages:** a rival moves to the next age when its residents reach 24 / 60 / 108 / 150 (Medieval / Renaissance / Industrial / Modern). A banner announces it.
- **Standings:** a HUD panel lists every town with population, age and wealth, sorted by population.
- **Goal and scenario:** a new goal kind, "outgrow every rival", and a fourth built-in scenario, **Island Rivalry** (Medieval, Normal, archipelago): outgrow every rival and reach 80 residents.
- **Rendering:** rival buildings use their rival's culture and age sprites, and carry a small pennant in the rival's colour, drawn in code. No new building art.
- **Saves:** a v8 → v9 migration gives existing saves no rivals and makes every building and ship the player's.

Deferred: trade with rivals (`add-rival-trade`), claiming islands with outposts, rival expansion to new islands, rival ships, rival research and culture-only buildings, diplomacy, war and multiplayer.

## Capabilities

### New Capabilities

- `rival-towns`: rival setup, identity, AI builder, rival economy and ages, standings, the outgrow goal and the Island Rivalry scenario.

### Modified Capabilities

- `buildings-and-construction`: buildings have an owner, foreign-island placement rejection, owner-checked demolition.
- `sea-transport`: ships have an owner.
- `economy`: tax and upkeep go to the owner's purse.
- `population-and-needs`: player totals exclude rival houses.
- `simulation-core`: rival commands share the command queue.
- `persistence-save-load`: the v8 → v9 migration.
- `rendering-2_5d`: owner culture and age lookup, owner pennant.
- `platform-shells`: rivals toggle, standings panel, foreign-island rejection text, read-only rival inspector, rival age banner.

## Impact

- **CityCore:** `Owner`, `RivalID`, `RivalTown`, `RivalColour`, `RivalAIState`, `Building.owner`, `Ship.owner`, `World.rivals`, `Command.rivalPlace`, `PlacementRejection.foreignIsland`, owner-aware `canPlace`, demolish, economy, population totals, goals, history events and research, `runRivalSystem`, `World.standings()`, `Goal.outgrowRivals`, `Scenario.islandRivalry` with `requiredLayout`, `WorldEvent.rivalAgeAdvanced`, `newGame(... rivals:)`, snapshot owner lookups.
- **CityPersistence:** save version 9.
- **CityRender2D:** per-owner culture and age sprite lookup, pennant overlay.
- **CityUI:** New Game toggle, standings panel, rejection text, inspector, banner.
