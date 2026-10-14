## Context

See proposal.md (Why). Today a lumberjack hut (`ProductionCatalog`: 1 wood per 30 ticks) clears one forest tile per cycle in row-major order within 2 tiles of its footprint (`World.clearHarvestedForest`, `visitCatchmentForest`). Nothing turns grass back into forest. A 2×2 hut's catchment is a 6×6 square of 32 tiles around its footprint, so even a fully wooded catchment lasts at most 32 cycles: 960 ticks, or 96 seconds at normal speed. The hut costs 2 wood, a farm 2 wood and a sawmill 4 wood plus 1 plank. Supply carriers feed the sawmill from the town center and warehouses until no wood is left. Rivals already avoid the cost trap: "a rival's lumberjack hut SHALL cost no materials".

### Playtest evidence

The playtest used a throwaway swift-testing harness (not committed) with `@testable import CityCore`. It drove a scripted player for 36,000 ticks (15 in-game years, about one hour of play) and printed one snapshot per year. The player's build rules came from the rival AI (threshold rules for food, wood and planks, then a script through bakery, tools, luxury goods and printing press), with a road planner that searched outward from the existing road network. Results on `main` at `187dbe0`:

| Run | Outcome |
|---|---|
| Single island, normal, seed 0 | Hut catchment empty by Spring 1201 (27 of 1,129 island forest tiles cut). Wood 0, planks 11, 5 empty houses, 0 residents. Bankrupt in Spring 1205. |
| Same, but farm and sawmill placed before the hut | Starter wood 6 spent on farm (2) and sawmill (4). The hut (2 wood) can never be placed again. 4 residents for 15 years, money idle at $2,303. |
| Archipelago, normal, seed 7 | 6 huts, all with no trees in reach within the first year (scattered single trees). 0 residents from 1202 on. Bankrupt in Summer 1209. |
| Archipelago rivals (seed 7, both runs) | Rival 1 at 0 residents for 15 years, treasury from $1,000 down to −$1,361. Rival 2 at 1 resident. |
| Guild Town scenario | Same soft-lock: bankrupt in 1212. Goals 0/30 merchants and 0/30 tools. |

A smarter bot built a new hut as soon as its huts held fewer than 10 + 2 × houses trees. It still soft-locked: the sawmill turned every incoming wood into planks before 2 wood could build up for the next hut. No run reached the citizen tier, so tiers, eras, research beyond milling, rival competition and scenario goals were never exercised.

A counterfactual run emulated this change inside the harness. Each hut got one forester planting every 45 ticks (90 in winter), and the town got 2 wood whenever it had none and its huts held fewer than 6 trees. On the single island (seed 0) the same bot then reached 16 residents with 5 citizens by Spring 1202, and 27 residents with 18 citizens by Spring 1203. It had bread, iron and tools running by 1203 and entered the Renaissance in autumn of the fourth year, with 51 residents, 14 of them merchants. The run needed the free 2 wood 24 times, and at the end 17 huts still had no trees in reach. One forester per hut at 45 ticks was not enough to keep up, which is why D1 uses a 40-tick cycle and still expects more than one forester per hut over time. The default single-island start also places the town center inside a mountain massif (168 of the 169 tiles within 6 tiles are mountain), and the nearest site with 4 or more trees in reach is 11 tiles away. That matters for start-site quality, but it is a separate issue (see Open Questions).

**Re-run after M2.** The same harness, now placing a forester after each hut, ran on single island seed 0, archipelago seed 7 and Guild Town (the same map as the single island). All three went bankrupt in 1202. Huts never ran bare: the forest in their reach stayed stocked. The wood stock still stayed at 0 because the sawmill consumes every log, and planks piled up to 40 because the bot cannot spend them. Without the forester step, single island seed 0 and Guild Town survived at 7 to 10 residents with $5,923 by 1215; archipelago seed 7 still went bankrupt. No run reached 20 citizens, and both archipelago rivals sat at 0 residents in 1215. Forests no longer run out, but money does, so the forester cycle was not retuned. The rival forester rule also applies during the opening, so a rival pays $60 per forester out of its starting treasury before its first houses earn anything. That is a likely early money drain and an input for `add-town-market` balancing. The money and food side belongs to `add-town-market`; the designer's emulation of forester plus market reached 70 residents.

## Goals / Non-Goals

**Goals:**
- Make wood renewable through a decision the player makes (where to put the forester), not a hidden regrowth timer.
- Remove the zero-wood soft-lock for every owner.
- Let the player see a hut or forester site's value before and after placing it.
- Keep rivals alive on the same rules.

**Non-Goals:**
- Tree growth stages, saplings, or a new terrain type.
- Natural forest spread without a forester.
- Buying goods with money (a market), tuning tier needs, or moving the town center start site.

## Decisions

### D1 — A forester building, not natural regrowth

The forester is a 2×2 building that turns one open grass tile in its catchment into forest every 40 ticks. A hut cuts one tree every 30 ticks, so one forester covers three quarters of a hut's harvest. Two foresters per three huts, or one per hut in a forest that is already there, keeps the wood supply level. The numbers are content values in the pack and are tuned there: the forester's `plantTicks` field, a building field added to the pack format for this change, holds the 40-tick cycle. The planting rule itself is code.

- **Alternative — forest regrows on its own** (a cleared tile turns back after N ticks, or grass beside forest spreads at random). Rejected: the player makes no decision, it eats building land in places the player did not pick, and random spread needs an RNG stream and is hard to reason about. Anno solved the same problem with a forester, and players expect it.
- **Alternative — huts never deplete.** Rejected: it removes the placement puzzle and makes the existing "no trees in reach" issue meaningless.
- **Alternative — saplings that mature after a season.** Rejected for now: it needs per-tile state in `World`, a save field, a sapling sprite and rules for building on a sapling. The 40-tick cycle and the winter half pace give enough lead time. A later change can add saplings without changing the forester's spec.

### D2 — Planting order and catchment

The catchment equals the lumberjack's: Chebyshev distance 2 from the footprint (`World.lumberjackCatchmentRadius`). The scan is row-major, and it plants the first tile that is grass, unoccupied and on an island the forester's owner owns. Row-major matches the hut's harvest order, so with overlapping catchments the forester refills the tiles the hut just cleared, top-left first. Beach and mountain are never planted, so shores and mines stay usable. The forester never plants on a road or under a building. A player who wants grass there must build on it first; building on forest is already allowed.

### D3 — No road, no storage, no recipe

The forester produces no goods, so it needs no carrier, road or goods buffer. That makes it cheap to drop into a forest edge. It is a `BuildingKind` with `effect: code` and no recipe (see `game-data-codegen` D-rules on code effects). A new `runForestrySystem` handles it, running right after `runProductionSystem` and before `runCarrierSystem`, so a tree planted on tick N can be cut on tick N + 1 at the earliest. Cycle progress reuses `productions[id].ticksThisCycle` (`ProductionProgress`), so saves need no new field. The forester joins `World.seasonalCrops` for the winter half pace, which keeps the existing "Winter slows crops" behaviour in one place.

- **Alternative — a recipe with no outputs (like the monument).** Rejected: the production system's stall logic, output-store checks and carrier spawning all assume goods. Planting would be one more special case inside it.

### D4 — Wood producers cost no materials

The lumberjack hut's `materials` become empty for every owner, and the forester has none either. Money is then the only gate on restarting wood. The existing rival-only exemption (`materialCost(of:for:)`) becomes the general rule, and its special case can go.

- **Alternative — reserve wood in the town center that supply carriers never take.** Rejected: it is invisible to the player and fights the sawmill's supply rule.
- **Alternative — sell wood for money at the town center.** Rejected here as a bigger economy change (it is the first runner-up in the backlog). It also does not fix rivals.

### D5 — Reporting trees and open ground

`World.catchmentCount(kind:anchor:owner:)` counts unoccupied forest for a hut and open grass for a forester, for built and unbuilt sites alike. It shares `visitCatchmentForest` with the hut and gets a sibling visitor for grass. `WorldSnapshot.catchments: [EntityID: Int]` holds the count for each player hut and forester. `BuildingIssue` gains `noRoomToPlant`. In `buildingIssues()` a forester is checked first and skips the road and storage checks (spec `warehouses-and-logistics`). The inspector's `problemText` gets the new wording. The hut's existing issue keeps its case and gains the forester hint in its text only.

The tool strip hint reads the count for the pending or hovered anchor from `GameSession`, calling the same world query on the session's current world. That runs only while one of the two kinds is armed, and it costs at most 36 tile reads per frame.

### D6 — Rivals replant

A fourth threshold rule, after the hut rule, places a forester while the rival has fewer foresters than huts. It counts every hut here, not only huts with 4 or more trees, because a thinned hut is the one that needs a forester most. Slot choice reuses `hutSlot`'s block search with a different score: the most open grass tiles shared with any single rival hut's catchment, minus 8 per block opened, with at least 4 shared tiles. The forester costs the rival no materials. The rule is a threshold rule, so it does not advance the script.

### Framework-free invariant

All simulation work stays in `CityCore` with Foundation only: the forestry system, the catchment query, the issue case and the rival rule. CityUI reads the snapshot and calls the world query. No Apple UI framework enters CityCore, and `scripts/check-no-apple-ui-imports.sh` keeps guarding it.

### Determinism

The forestry system visits foresters sorted by `EntityID.raw`, like `operationalProducersInEntityOrder`. Each forester scans its catchment in fixed row-major order and uses integer tick counts only. It reads no RNG and no wall clock, and it never iterates a `Dictionary` to choose a tile. Two foresters with overlapping catchments resolve by entity order: the lower ID plants first and the next one sees the tile as forest. The rival forester slot search inherits `RivalTownPlan`'s fixed block order. The cross-platform `DeterminismFixture` output changes, because rivals build foresters, but macOS and Linux must still match byte for byte.

## Risks / Trade-offs

- [Foresters plant over grass the player wanted for houses] → It only plants within 2 tiles of its own footprint, the inspector shows open grass in reach, and demolishing the forester stops it. Building on forest stays allowed, so planted land is not lost.
- [Free huts make early wood too easy] → The money cost ($80) still applies, and the hut still needs trees in reach. Watch the first-year balance in the playtest numbers after M1 and tune the cost in the pack if needed.
- [40-tick planting is too fast or too slow] → It is one pack value. The M1 acceptance test checks that a hut with one forester keeps producing over 2,400 ticks. Because the hut cuts faster (30 ticks) than one forester plants (40), its catchment does run bare for moments, so the scenario bounds that: after the first harvest it is never without forest for longer than one planting cycle. The M2 playtest re-run checks a full game.
- [Rival foresters change the archipelago fixture and rival pacing] → This is expected. The "Rival buildings touch a road" scenario still holds because foresters go through the same slot and ring-road logic.
- [Touching CityUI views that `add-tvos-port` also edits] → Changes are limited to `InspectorViewModel` lines, `problemText`, and the tool strip hint string. The tvOS change modifies the "Tool strip" requirement, so this change adds a separate requirement and does not modify that one.
- [The `lumberjack-hut` scenario title "First lumberjack placement consumes starter wood" no longer describes the outcome] → OpenSpec refuses to drop or rename a scenario in a MODIFIED block, so the delta removes "Town center starter inventory" and adds the same rules as "Town center starter goods", where the scenario is "First lumberjack placement keeps the starter goods". Until the change is archived, the main spec still lists the old title, which `make test-scenarios` reports as unmapped.

## Migration Plan

Saves load unchanged: no new stored fields. A save can hold a lumberjack hut that is still waiting for wood. Today a waiting site only switches to active construction when a delivery arrives, and no delivery comes for a cost that is now empty. M1 therefore makes `advanceBuildings` move a waiting site to active when its catalog material cost is already covered by what was delivered, and tests it with a `waitingForMaterials` hut fixture. Rollback is a revert. Saves that contain a forester do not load in older builds, as with any new `BuildingKind`.

## Open Questions

- Should the town center start site prefer land with forest in reach? The playtest found the seed-0 single island starts in mountains. This is a world-gen change and does not affect this design.
- Does the forester need its own audio cue? A `forestPlanted` binding can be added to `Resources/Audio/bindings.json` later without spec changes.
