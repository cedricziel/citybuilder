## Why

Most new games start on bad land. World generation puts each town center on the first buildable 3×3 spot nearest the island's bounding-box centre and does not look at what is around it. On the single island that spot is inside the mountain massif: the town center sits at (45,46) with 334 mountain tiles and 18 grass tiles within 8 tiles. On the archipelago, grass is plentiful but trees are not, so the best lumberjack hut site near a start usually reaches only 9 trees. By the fairness test below, 0 of 5 single-island starts, 3 of 150 archipelago player homes and 10 of 300 rival starts are fair. `add-forestry` makes wood renewable, but a forester still needs a hut with trees to pair with, and its playtest flagged the mountain start as a separate world-gen issue (its Open Questions). This change fixes it.

## What Changes

- **BREAKING (world generation):** each island's town center goes on the nearest site to the island centre where the 3×3 footprint and the 1-tile ring around it are all grass, and the 19×19 area within 8 tiles of the footprint holds at least 150 grass tiles and at most 25% mountain. The starter road ring therefore always fits on grass.
- **BREAKING (world generation):** after the town center is placed, world generation plants a 6×6 **starter grove** on the nearest 6×6 square of grass or forest outside the town center and its ring: forest everywhere except a 2×2 grass clearing in the middle, which is a ready lumberjack hut site with 32 trees in reach.
- When no site meets the thresholds, a fallback picks the all-grass site with the most grass in reach, and if there is none, the current rule. The grove is skipped only when no 6×6 square qualifies.
- Every island gets the same rules, so rival starts are as fair as the player's.
- Terrain stays a pure function of layout and seed. Difficulty and the rival count do not change where town centers or groves go.
- A seed-sweep acceptance test measures fairness across archipelago seeds 0–49 and the single island.

Out of scope: changing the island generators themselves (silhouettes, mountain cores, forest density), resource placement such as ore near the start, and moving town centers in existing saves.

## Capabilities

### New Capabilities
- (none)

### Modified Capabilities
- `world-terrain`: a new requirement "Fair start sites" covering town center site choice, the fallback, and the fairness measure; a new requirement "Starter grove"; and a new requirement "Start placement independent of difficulty", so rivals get the same rule and terrain does not depend on difficulty or the rival toggle.
- `buildings-and-construction`: "Town center starter road" gains a scenario that the full 16-tile ring is laid on every new game, because the site rule guarantees grass under it.

## Impact

- **CityCore**: a new `World+StartSites.swift` holds the site search, the fallback and the grove stamp; `seedTownCenters` in `World+Fixture.swift` calls them in place of `findFootprint`. Terrain changes inside `newGame`, after island detection; the grove turns grass into forest only, so the island list, island IDs and tile counts do not change. No new stored state and no save format change: saves carry their terrain and buildings, so loading an existing game is unaffected.
- **Determinism**: every new game's terrain and town center positions change, so the `DeterminismFixture` output changes. CI compares macOS with Linux on the same commit, so it stays green as long as the new code avoids floating point and `Dictionary` iteration order. The site search and the grove use only integer tile counts.
- **game-data-codegen baseline**: `openspec/changes/game-data-codegen/baseline/determinism.json` and `determinism-36k.json` record the fixture output on `main` before codegen. This change alters that output on purpose, so the implementing PR regenerates both files with `SWIFT_DETERMINISTIC_HASHING=1` and says so in its description, as the codegen design (content changes) requires.
- **Tests**: tests that pin a town center position or count trees near the start of `World.newGame()` move with it (for example `WaitingBadgeTests` uses (45,46), and rival-grid tests derive tiles from the town center anchor). Playtest numbers in `add-forestry` and `add-town-market` (#36) were taken on the old seed-0 single-island start and will differ after this change.
- **Rivals**: rival town centers move to fair sites too. The rival road grid is anchored to the town center, so it moves with it; the grid may cut through the grove, which is allowed.
- No new build-time tools.
