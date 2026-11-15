## Why

Every island can make every good, so ships, routes and rival ports are optional: a player can reach merchants without ever leaving home. `Climate` is stored on every island but gates nothing; `world-terrain` names this change as the follow-up and it was never written. From the 2026-11-14 audit (epic #395); builds on the soil-fertility idea of #261, cut down to what is needed (#400).

## What Changes

- Every island gets a **resource profile** at world generation: a soil yield per crop family (field, grain, pasture, garden), whether it has ore, and a forest richness label. Climate and the world seed drive it. Yields are whole percentages; a crop building's cycle is its recipe cycle × 100 / yield, rounded up.
- **Luxury crops belong to a climate.** Hops grow on temperate islands; grapes, tea leaves and coffee cherries on tropical ones. A garden cannot be placed on an island of the other climate.
- **Home and colony islands.** In an archipelago game the home island's climate is the one the player's luxury crop does *not* grow in, and the smallest other island with a town center (the **colony island**) gets the climate it does grow in. Merchants need the luxury, so the top tier needs a second island and a route. Rivals are never seated on the colony island. The home island keeps food, grain and pasture at 100%, its starter grove and its mine site, so food, wood, planks, bread, tools and cloth all stay possible at home.
- **Luxury import.** While the player's luxury crop cannot grow on their home island, the town market sells the culture's luxury good: 12 a season at 200% of its base price. A few merchants are possible without a colony; a growing merchant quarter needs one.
- **Mines need ore.** A mine cannot be placed on an island without ore. The home and colony islands always have ore; every other island has it on a seeded coin flip.
- **Single-island games** get a complete profile: every crop at 100% whatever the climate, and ore. They play exactly as today.
- **Old saves** load with the complete profile on every island, so nothing a player built stops working.
- **Seeing it with existing UI only:** the island caption in the status pill names the climate, the stocks tray header gets one profile line, the placement count capsule shows the soil yield for crop buildings, the inspector of a crop building shows its soil, and two new placement rejection messages explain the rules. German for every new string.
- Later milestones (not shippable tonight): campaign directives for soil and ore (M2), a PlayerBot that colonises (M2), per-tile fertility from #261 and a profile overlay through Claude Design (M3).

## Capabilities

### New Capabilities

None. The profile belongs to `world-terrain`; its effects belong to the capabilities below.

### Modified Capabilities

- `world-terrain`: **BREAKING** (rule change, saves stay compatible) Climate band metadata now drives gameplay and, in archipelago games, follows the player's culture on the home and colony islands; new requirements for the island resource profile, the home and colony islands, ore and forest richness.
- `goods-and-production`: crop cycles scale with soil yield; gardens need their climate; mines need ore.
- `town-market`: the luxury import line.
- `rival-towns`: rivals leave the colony island free.
- `persistence-save-load`: saves without profiles load with the complete profile.
- `platform-shells`: the climate caption, the tray's profile line, the soil capsule, the soil inspector line and the two rejection messages.

## Impact

- **CityCore** (framework-free stays true: integer math, no Foundation beyond what is already used): `WorldLayout.swift` (`Island` gains `profile`), new `IslandProfile.swift`, `World+Fixture.swift` (`generate` assigns profiles after `seedTownCenters` and before `seedRivals`), `World+Rivals.swift` (skip the colony island), `Systems.swift` (yield-scaled cycle), `World+Placement.swift` and `Terrain.swift` (`PlacementRejection.wrongClimate`, `.noOre`), `World+Market.swift`, `TownMarket.swift` (import line), `WorldSnapshot.swift` (`IslandSummary.climate`, `.profile`).
- **Game data**: a new singleton kind `IslandProfiles` in `packs/core.yaml`; building fields `cropFamily` (farm, grain-farm, sheep-farm, the four gardens) and `climate` (the four gardens). GameDataGen (`Loader.swift`, `Model.swift`, `SwiftEmitter.swift`, `pack.schema.json`) learns both; `make gamedata` regenerates `Generated/`.
- **CityUI**: `StatusPillView.swift`, `HUDViewModel.swift`, `GameSession+AreaOfEffect.swift`, `PlacementRejectionText.swift`, an inspector line, `Localizable.xcstrings` (English and German).
- **CityPersistence**: no version bump; `Island` decodes a missing profile as the complete one. A fixture test.
- **Tests**: PlayerBot buys the luxury import when its home cannot grow the luxury. Balance sweeps to rerun are listed in design.md D12.
- No new build-time tools.
- Coordinates with `add-campaigns` (soil and ore directives in M2) and the random-maps work (profiles read whatever terrain the generator makes; the colony rule needs at least `rivals + 2` islands, else the import is the only luxury source).
