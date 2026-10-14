## Why

A Mac playtest of a fresh default game stalled within one in-game year: population 0, money flat, no food or wood, and no on-screen explanation. The town center starts without a road, so nothing can reach its goods; producers said "operational, road connected" while their road never reached storage; Research opened empty; Quit from the pause menu silently dropped progress. The night tint also made the map hard to read.

## What Changes

- World generation rings each player town center with free road (rivals keep laying their own grid).
- The simulation reports why a player house or producer is idle: no road, no route to storage, no forest in reach, missing inputs, or a full store. The snapshot carries it and the inspector callout shows it as a key line.
- The pause menu's Quit asks "Save and Quit / Quit Without Saving / Cancel"; a failed save keeps the game open.
- **BREAKING** Night darkness drops from 0.55 to 0.4.
- Mac HUD sheets get a minimum size so list-based panels (Research, Goals, Standings) no longer collapse to nothing.
- The stocks tray names each good, every good chip has a hover tooltip, and cost chips spell out "in store, needed".
- The inspector callout uses a more opaque material and higher-contrast detail text.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `buildings-and-construction`: town center starter road.
- `warehouses-and-logistics`: buildings report why they are idle.
- `platform-shells`: inspector key lines include the problem; Quit asks whether to save.
- `city-life`: night darkness is 0.4.

## Impact

- CityCore: `World+Fixture` (starter road), new `World+BuildingIssues`, `WorldSnapshot.buildingIssues`, `TimeOfDay.nightDarkness`. Starter roads change fresh-world state, but generation stays a pure function of seed and settings.
- CityUI: inspector model and callout, pause menu, stocks tray, tool strip, sheet sizing.
- CitybuilderMac: Quit and Cmd-Q close open sheets before terminating.
- No new build-time tools.
