## Why

Wood is the base of every building and of the citizens' planks, but forest never comes back. Each lumberjack cycle turns a forest tile into grass for good, so a hut empties its catchment in one to two minutes, and the island runs dry. Once the sawmill has turned the last wood into planks, the player cannot afford a new lumberjack hut (2 wood) or a farm (2 wood). Money cannot buy wood on a single island, so the game is soft-locked.

A headless playtest showed this in every run where a scripted player built a normal opening. The player bot used the same build-order rules as the rival AI, on single-island and archipelago maps. It went bankrupt or stalled at 0 residents within the first two in-game years. No run reached citizens, so the rest of the game (tiers, research eras, ages, rivals, scenarios) never came into play. Rivals on the archipelago collapse the same way: one stayed at 0 residents with a negative treasury for 15 years.

## What Changes

- Add a **forester**: a cheap 2×2 building that plants one forest tile per cycle on open grass within 2 tiles of its footprint. It plants at half pace in winter, like crops. It needs no road, no storage and no inputs, and it stops when its catchment holds no open grass. Paired with a lumberjack hut, it makes wood a renewable, place-it-right production loop, as in Anno.
- **BREAKING (balance):** the lumberjack hut and the forester cost money only, no materials. Rivals already build huts for free. With this rule, a town with money can always restart its wood supply, so the zero-wood soft-lock cannot happen.
- Lumberjack huts and foresters report trees and open ground in reach. The snapshot carries the count, and the inspector shows it as a key line ("Trees in reach: 7"). Two new problem texts tell the player what to do: "No forest within 2 tiles: build a forester beside it" for a hut, and "No open grass within 2 tiles to plant" for a forester.
- While the player places a lumberjack hut or a forester, the tool strip hint shows how many trees or how much open grass the chosen tile would reach, so the player can choose a good site before building.
- Rivals build a forester for each lumberjack hut, beside the hut, so archipelago rivals keep a wood supply.

Out of scope: tree growth stages (saplings), a separate sapling sprite, natural regrowth without a forester, and a market for buying goods with money. A market is a strong follow-up, but it is a separate economy change.

## Capabilities

### New Capabilities
- `forestry`: the forester building, how it plants (catchment, scan order, winter pace, stopping), and the trees and open ground reported for huts and foresters.

### Modified Capabilities
- `buildings-and-construction`: the lumberjack hut and the forester have no material cost. The town center starter inventory scenarios that depend on hut costs change.
- `warehouses-and-logistics`: "Buildings report why they are idle" covers the forester (no open grass in reach), and the forester needs no road or storage.
- `rival-towns`: the rival build order adds a forester threshold rule, and the town plan gets a forester slot rule.
- `platform-shells`: a new requirement for the inspector's trees-in-reach line, the new problem texts, and the catchment hint while placing.

## Impact

- **Depends on** `game-data-codegen` through its milestone M3 (catalog generation), as `tier-needs-data` does. The forester is a new `Building` item in the core pack (`effect: code`, no recipe). The lumberjack hut's `materials` become empty in the same pack. Its planting behaviour is hand-written Swift, following the codegen rule that behaviour stays in code.
- **CityCore**: a new `runForestrySystem` (after production, before carriers), forester cycle progress kept in `productions`, the forester in the seasonal set, new `BuildingIssue` cases, `WorldSnapshot.catchments`, a catchment preview query, and the rival AI's forester rule and slot. Save format: no new stored state. A `BuildingKind` case is added, which older builds cannot decode (the same as any new building).
- **CityUI**: inspector key line and problem texts, the tool strip hint while placing. These views are also touched by `add-tvos-port`, so expect small merge conflicts there.
- **Art**: one new catalog entry, `Resources/Sprites.style/catalog/forester.md`, generated with `make sprites`. The existing grass and forest tiles show the planting. No new terrain type.
- **Determinism**: the `DeterminismFixture` world (an archipelago with rivals) changes, because rivals now build foresters. CI compares macOS and Linux output with each other, so no committed baseline needs updating, but the forestry system must stay free of floating point and of `Dictionary` iteration order.
- No new build-time tools.
