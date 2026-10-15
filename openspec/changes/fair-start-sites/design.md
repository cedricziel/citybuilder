## Context

See proposal.md (Why). `World.newGame` builds the terrain grid (`IslandGenerator` for the single island, `ArchipelagoGenerator` for the archipelago), detects islands, then `seedTownCenters` puts a 3×3 town center on every island. `findFootprint` starts at the island's bounding-box centre and walks Chebyshev rings outward until the footprint is free and not water. It accepts mountain, beach and forest. `seedRivals` then hands the town centers of the largest non-home islands to rivals, and `seedStarterRoads` rings each player town center with road on every non-water, unoccupied tile touching the footprint (`buildings-and-construction` / Town center starter road).

The two generators have different weaknesses:

- The single island ignores the seed and has a mountain core of radius about 12 at the map centre, exactly where the search starts.
- The archipelago islands are mostly grass. Forest is a per-tile hash dot at 10 in 64 (about 16%), so trees are spread thin and a lumberjack hut's 32-tile catchment holds about 5 on average.

A lumberjack hut reaches forest within Chebyshev distance 2 of its 2×2 footprint, a 6×6 square (`World.lumberjackCatchmentRadius`, `add-forestry`). `add-forestry` makes huts free of materials and adds the forester, but a forester only refills a catchment; it does not help a start whose nearest good hut site is 11 tiles away in the mountains (`add-forestry` design, Context).

### The fairness measure

All numbers below use one measure, which the acceptance test (D7) also uses. For a town center with anchor `(ax, ay)`:

- **Start area**: the tiles within Chebyshev distance 8 of the 3×3 footprint, the 19×19 square from `(ax − 8, ay − 8)` to `(ax + 10, ay + 10)`, clipped to the map.
- **Grass** and **mountain**: tile counts by terrain in the start area.
- **Hut site trees**: the most unoccupied forest tiles in the catchment of any 2×2 lumberjack hut anchor whose footprint lies in the start area on unoccupied grass.
- A start is **fair** when grass ≥ 150, mountain ≤ 25% of the start area's tiles, and hut site trees ≥ 12.

12 trees is 12 wood from one hut before it needs a forester, enough for the opening placements. 150 grass is room for the starter ring, a hut, a forester, a farm, a sawmill and the first houses with space to spare.

### Evidence

The previous design pass measured the problem with an uncommitted scratch harness over archipelago seeds 0–49 × 3 difficulties (150 runs; the single island ignores the seed, so all its runs are one map):

| Start | Before | Site rule only (D1) | Site rule + grove (D1 + D3) |
|---|---|---|---|
| Single island | 0 of 5 fair; TC at (45,46) with 334 mountain and 18 grass | 5 of 5; TC at (47,30), 209 grass, best hut site 25 trees | 5 of 5 |
| Archipelago player home | 3 of 150; median hut site 9 trees (range 7–15) | 12 of 150 | 150 of 150 |
| Archipelago rivals | 10 of 300; median 9 trees (range 6–14) | — | 300 of 300 |
| Other player islands | 1 of 100 | — | 100 of 100 |

With the grove the median hut site reached 21 trees, minimum 12, and the grove never failed to find a square. On the archipelago grass is never the binding limit; trees are.

A second, independent scratch harness written for this proposal (not committed) re-measured with the exact definitions above, the nearest-site order of D2, and the grove of D3:

| Start | Before | Site rule only | Site rule + grove |
|---|---|---|---|
| Single island | not fair: TC at (45,46), 334 mountain, 18 grass, 11 trees | fair: TC at (39,60), 192 grass, 90 mountain, 12 trees | fair: 169 grass, 32 trees |
| Archipelago player home (150) | 24 fair; median 10 trees (8–14) | 24 fair | 150 fair; 32 trees each |
| Archipelago rivals (300) | 38 fair; median 10 (8–14) | 43 fair | 300 fair |
| Other player islands (300) | 28 fair; median 10 (7–14) | 41 fair | 300 fair |

The single-island "before" figures match exactly. The two harnesses differ in their hut site definition and search order, so the absolute counts differ (the first counted islands per difficulty differently and found fewer trees per site), but both reach the same conclusions: the site rule alone fixes the single island and leaves most archipelago starts short of trees; the grove makes every start fair; no fallback and no grove failure occurred in 150 runs. The M1 acceptance test (D7) fixes the definitions in code, so the numbers in its output become the reference.

**Reference numbers (M1 acceptance test, `FairStartSiteTests`).** Archipelago seeds 0–49 at Easy, Normal and Hard plus the single island: 751 of 751 town centers fair (750 archipelago, 1 single island), no fallback placement, terrain identical across the three difficulties of every seed. Every start's best hut site reaches 32 trees, the grove's clearing. The single-island town center stands at (39,60) with 169 grass and 90 of 361 mountain tiles in its start area.

**Playtest re-run (M2).** The `add-forestry` headless harness (not committed) was re-run on `main` (forester merged, old start) and on this change. A scripted player follows the rival AI's rules on the player's island for 36,000 ticks (15 in-game years). It builds a forester for every hut. Both builds were release builds, and the two worlds differ only in the start site, the grove and the camera. The figures are end-of-year residents, balance, wood and planks for the player, and residents per rival.

| Run | `main` | fair start |
|---|---|---|
| Single island seed 0, 1201 | 4 residents, $70, 0 wood, 23 planks, 2 huts (1 bare) | 8 residents, $94, 0 wood, 24 planks, 4 huts (3 bare) |
| Single island seed 0, 1202 | 3 residents, $83, 39 planks | 15 residents, $69, 39 planks |
| Single island seed 0, end | bankrupt in 1205 (18 residents in 1203 at best) | bankrupt in 1203 |
| Archipelago seed 7, player | 0 residents, bankrupt in 1202 | 0 residents, bankrupt in 1202 |
| Archipelago seed 7, rivals 1201–1205 | Lowtide 0 (treasury −$79), Stoneholm 1–3 | Lowtide 6–10, Stoneholm 8–16 (the same range through 1215) |

The fair start helps rivals clearly: on `main` the archipelago rivals stay near 0 residents through 1205, and with the fair start both hold a small town. For the player bot it doubles the residents of the first two years on the single island, but the run still ends bankrupt, one year earlier than on `main`. In every run wood stays at 0 while planks pile up to the town center's 40-unit cap. The sawmill turns all wood into planks, and nothing can sell the surplus. That is the soft-lock `add-town-market` describes, not a start-site problem, so this change leaves it to that change. The earlier bankruptcy is input for balancing the market. A better start lets the bot build and pay upkeep sooner, so it runs out of money sooner while its planks have no buyer. A market that buys surplus planks early would turn that head start into income. No run reached 20 citizens. These runs predate rival foresters (#40) and the grass-after-grove check, and neither changes the player's opening on the single island. The bot is the `add-forestry` harness bot, so these runs compare starts with each other; they do not measure how a human plays.

**Simulator check (M2).** A new single-island game on the iPhone 17 simulator opens on the town center, which stands on grass with its road ring. The edge of the mountain core is a few tiles away, and the starter grove with its grass clearing is next to the road ring. A new archipelago game (seed 0, Normal, rivals on) opens on the home town center on grass, with the denser grove block beside the ring and the island's scattered forest dots around it. Before task 1.12, the single-island camera opened on the map centre and the screen showed only mountain.

## Goals / Non-Goals

**Goals:**
- Every town center, the player's and each rival's, starts on grass with room to build, little mountain, and a lumberjack hut site with trees.
- Terrain and town center positions stay a pure function of layout and seed.
- Fairness is measured by a test across seeds, not argued from one map.

**Non-Goals:**
- Changing the island generators' silhouettes, mountain cores or forest density. That would change every island, not only the starts, and break the single island's fixed look.
- Placing ore, fertile land or other resources near the start. Mines still go on the island's mountains, which the 25% cap does not remove.
- Re-siting town centers in loaded saves.

## Decisions

### D1 — A start site is a 5×5 all-grass square with fair surroundings

A candidate anchor `(ax, ay)` qualifies when the 5×5 square from `(ax − 1, ay − 1)` to `(ax + 3, ay + 3)` (the footprint plus the starter road ring) is all grass, unoccupied and on the island, and the start area around it holds at least 150 grass tiles and at most 25% mountain. Grass is counted as it will be once that anchor's grove (D3) is planted, because the grove can turn up to 32 grass tiles into forest and fairness is measured after generation. A candidate with fewer than 146 grass before the grove is skipped without trying a grove, since the 2×2 clearing adds at most 4. Requiring the ring to be grass means the starter road always gets all 16 tiles, and the town center never stands on mountain, beach or forest.

- **Alternative — score every site and take the best.** Rejected: a best-of search moves starts far from the island centre to chase a few extra grass tiles, and it is slower. Thresholds keep the start near the centre and still guarantee fairness.
- **Alternative — 3×3 all grass, ring allowed on any land.** Rejected: a ring on beach or mountain is legal road but leaves the start area cramped, and the measured single-island massif edge produced such sites.

### D2 — Nearest to the island centre by Euclidean distance, ties by row then column

The search target is the anchor that would centre the footprint on the island's bounding box, `(cx − 1, cy − 1)` with `cx, cy` the box midpoint (integer division), as today. Candidates are ordered by squared Euclidean distance to the target, then by `y`, then by `x`, and the first that qualifies wins. Integer arithmetic only.

- **Alternative — keep the Chebyshev ring walk.** Rejected: within a ring it scans row-major from the top-left corner, so a site straight below the centre loses to one at the far corner of the same ring. On the single island that moved the start 11 tiles diagonally instead of along the shortest way out of the massif.

### D3 — A 6×6 starter grove beside every town center

After the town center is placed, world generation stamps a starter grove: the 6×6 square nearest the town center whose tiles are all grass or forest, on the same island, and outside the 5×5 town center square. "Nearest" orders the square's top-left corner by squared Euclidean distance to `(ax − 2, ay − 2)`, then `y`, then `x`, searching up to 12 tiles away. The grove's tiles become forest, except the 2×2 at offsets (2,2)–(3,3) of the square, which become grass. That clearing is a lumberjack hut site whose catchment is the whole grove: 32 trees.

The grove only turns grass into forest and forest into grass (the clearing), both land, so the connected components, island IDs, tile counts and bounding boxes do not change and the island list stays valid without re-detection.

- **Alternative — raise forest density near the start.** Rejected: a hash-based density bump gives an uneven number of trees per hut site and still misses the threshold on unlucky seeds.
- **Alternative — demand ≥12 trees in D1's site rule.** Rejected: measured, the rule alone made 12 of 150 (or 24 of 150 in the re-measurement) archipelago homes fair, because thin forest rarely clusters 12 trees within reach anywhere near the centre.
- **Alternative — a starter lumberjack hut instead of trees.** Rejected: it removes the first placement decision and skips the hut's cost and construction, which balance depends on.

### D4 — Fallbacks

If no anchor qualifies under D1, the town center goes on the 5×5 all-grass anchor with the most grass in its start area, ties broken by the D2 order. If no 5×5 all-grass anchor exists, the current rule applies: the D2-ordered first anchor whose 3×3 footprint is free land. If no 6×6 square qualifies for the grove, no grove is stamped. An island too small for any town center still gets none, as today. Neither fallback triggered in either harness, so they guard small or future islands, not today's maps.

### D5 — The same rules for every island, independent of difficulty

Town centers and groves are placed on every island before `seedRivals` chooses which islands rivals get. Placement depends only on the terrain, and the terrain only on layout and seed, so difficulty and the rival toggle change who owns a town center but never where it or its grove is. Rivals thereby get starts exactly as fair as the player's. The rival road grid is anchored to the town center and moves with it; where it crosses the grove, roads go on forest as they may today.

### D6 — Determinism and CityCore invariants

The site search and the grove use integer tile counts, integer squared distances and arrays in index order. No floating point, no `Dictionary` iteration, no RNG draw: the grove consumes no randomness, so later RNG-driven systems see the same stream as before for a given seed. The single island's generator keeps its existing `Double` math unchanged. CityCore stays framework-free: the change is Foundation-only code in `World+StartSites.swift`, called from `seedTownCenters` in `World+Fixture.swift`.

The `DeterminismFixture` world (archipelago, seed 0xC17B) changes because its town centers and terrain move. CI compares macOS and Linux output on the same commit, so it needs no baseline update. The `game-data-codegen` baseline under `openspec/changes/game-data-codegen/baseline/` records the fixture on an older `main` and is compared by hand, not by CI. This change alters that output on purpose, so the implementing PR regenerates `determinism.json` and `determinism-36k.json` with `SWIFT_DETERMINISTIC_HASHING=1` and states it in the PR description, following the codegen design's rule for content changes.

### D7 — A seed-sweep acceptance test

A CityCore test generates the single island and archipelago seeds 0–49 at Easy, Normal and Hard, measures every town center with the fairness measure above (after starter roads, so occupied tiles count), and requires every start to be fair, no fallback to have triggered, and terrain to be byte-identical across the three difficulties of each seed. It prints the fair counts and the hut-site tree median and range so later generator changes can be compared. The scratch harness ran a similar sweep in about 25 seconds, so it runs with the normal suite.

## Risks / Trade-offs

- [Every new game's map looks different near the start] → Intended. Existing saves keep their terrain and buildings, so only new games change.
- [The grove is a visibly square patch] → It is 6×6 among forest dots and is cut into by roads and buildings within minutes. If it looks artificial in the playtest, a follow-up can round its corners; corners hold 4 of 32 trees, so the threshold still holds.
- [Starts move away from mountains, so the first mine is farther away] → The cap is 25% of the start area, not zero, and the single-island start still has 90 mountain tiles in reach. Mines come later in the build order.
- [Tests pinned to the old town center position break] → M1 updates them in the same PR (`WaitingBadgeTests`, rival grid and starter tests that derive from the anchor).
- [Playtest numbers in `add-forestry` and `add-town-market` were taken on the old start] → They stay valid as history; their re-runs after this change will use the new start.
- [The two harnesses disagree on absolute counts] → The acceptance test fixes the definitions; its printed numbers replace both.

## Migration Plan

No save migration: generation runs only for new games. Rollback is reverting the PR; saves made in between keep their terrain.
