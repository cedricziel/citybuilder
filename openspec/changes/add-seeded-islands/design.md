## Context

Two generators build every map today (`Packages/CityCore/Sources/CityCore/`):

- `IslandGenerator` (`IslandGenerator.swift`) draws one 96×96 island from fixed `Double` sine waves and takes no seed.
- `ArchipelagoGenerator` (`WorldLayout.swift`) paints five fixed integer ellipses on 300×300 and lets the seed scatter forest dots (10 of 64 hash buckets) and mountain dots (1 of 64).

`World.newGame(layout:seed:…)` (`World+Fixture.swift`) picks the generator, then `World.generate` detects islands (`IslandDetector`), seeds a town center on every island with a fair start site, plants its starter grove and raises a mine site (`World+StartSites.swift`), seats rivals on the largest other islands (`World+Rivals.swift`, 1/2/3 rivals at Easy/Normal/Hard), lays the starter roads and centers the camera.

Things that pin today's maps:

- Over 100 tests call `World.newGame(layout:seed:)` and some assert exact tiles (for example `StarterMineSiteTests`: "archipelago seed 1 raises nine tiles, mine site 6 road tiles away").
- `DeterminismFixture` runs `newGame(layout: .archipelago, seed: 0xC17B)` on macOS and Linux and diffs the JSON.
- `UITestSeed` and the title backdrop (`TitleBackdrop.makeSnapshot()` → `UITestSeed.townWorld`) use single island, seed 0.
- Scenarios (`Scenario.requiredLayout`) and campaign chapters (`ChapterSetup`, `ChapterEmitter`) pass a layout and a fixed seed, and the terrain directives (`thinForest`, `pushMineOut`, `raiseMineSite`) were tuned on those maps.
- The PlayerBot sweeps (`scripts/sweeps`) and their baselines run on both classic maps.

Saves: `World` is `Codable` end to end. `terrainGrid`, `mapWidth`, `mapHeight`, `islands` and `layout` are encoded (`SaveStore` writes `JSONEncoder` output of `SaveFile`, and `SaveStore.load` checks `terrainGrid.count == mapWidth * mapHeight`). Loading never calls a generator, so no existing save changes when generation changes.

## Goals / Non-Goals

**Goals:**

- The seed decides the island outline and size, and in an archipelago also the island count, positions and sizes.
- Every start is fair on every seed, with a proof by construction plus validation and a bounded retry.
- Byte-equal terrain on macOS and Linux.
- Classic maps stay reachable and byte-identical, so nothing pinned to them moves.
- Sandbox New Game offers map size and island count with the existing dialog controls.

**Non-Goals:**

- Per-island resource profiles and climate overrides (`add-island-specialization`, PR #439). D9 says how the two fit.
- New terrain types, rivers, elevation or new art.
- Generated maps for scenarios and campaign chapters (follow-up M3, not in this change's M1 or M2).
- Moving town-center placement rules: the existing fair-start, grove and mine-site rules run unchanged on generated terrain.

## Decisions

### D1. Map style is separate from layout; classic is a preset

`WorldLayout` (`single-island`, `archipelago`) keeps its meaning: the topology. A new value type chooses how the terrain is made:

```swift
// Packages/CityCore/Sources/CityCore/MapSettings.swift
public enum MapStyle: String, Codable, Sendable, CaseIterable { case classic, generated }
public enum MapSize: String, Codable, Sendable, CaseIterable { case small, medium, large }
public struct MapSettings: Codable, Sendable, Hashable {
    public let style: MapStyle
    public let size: MapSize          // .medium for classic
    public let islandCount: Int       // 1 for single island; 3...7 for a generated archipelago; 5 for the classic archipelago
    public static let classic: MapSettings            // style .classic, size .medium, islandCount 0 (resolved per layout)
    public static func generated(size: MapSize, islandCount: Int) -> MapSettings
    public static let islandCounts = 3 ... 7
    public func side(for layout: WorldLayout) -> Int // D2 table
}
```

`World.newGame(layout:seed:…)` gains a last parameter `map: MapSettings = .classic`. Every existing caller keeps the classic map without a code change. That is the decision for "do old layouts stay available": yes, as the `classic` style of each layout, built by the untouched `IslandGenerator` and `ArchipelagoGenerator`.

`World` gains `public internal(set) var map: MapSettings` (decoded as `.classic` when missing) and `public internal(set) var mapAttempt: Int?` (the generation attempt that passed, nil for classic maps and for the classic fallback). A generated request that fell back is `map.style == .generated && mapAttempt == nil`.

Alternative rejected: add `WorldLayout` cases such as `generated-archipelago`. Every `layout == .archipelago` check (rivals, the rival toggle, chapter validation, the "rivals need the archipelago layout" rule) would need a second case, and old saves would mix topology with style.

### D2. Map sides

| Layout | Small | Medium | Large | Classic |
|---|---|---|---|---|
| Single island | 80 | 96 | 128 | 96 |
| Archipelago | 240 | 300 | 360 | 300 |

Medium matches the classic sides, so the balance tuned on today's maps carries over. Small single island keeps the spec's ≥ 80×80 target. Large stops at 360 because the save, the ground macro field and the island map grow with the square of the side (D10, D11).

### D3. Deterministic integer noise

All generation code lives in `Packages/CityCore/Sources/CityCore/SeededIslands/` and uses only `Int`/`Int64`/`UInt64` arithmetic. There is no `Double`, `Float`, `sin` or `sqrt`, no `Dictionary` or `Set` iteration, and no system randomness. `.swiftlint.yml` extends the `tick_float_ban` rule's `included` to `Packages/CityCore/Sources/CityCore/(Systems|SeededIslands)/.*\.swift`.

Hash (`SeededIslands/MapHash.swift`):

```
func mapHash(_ seed: UInt64, _ salt: UInt64, _ x: Int, _ y: Int) -> UInt64 {
    var h = seed &+ salt &* 0x9E37_79B9_7F4A_7C15
    h &+= UInt64(bitPattern: Int64(x)) &* 0xBF58_476D_1CE4_E5B9
    h &+= UInt64(bitPattern: Int64(y)) &* 0x94D0_49BB_1331_11EB
    h ^= h >> 30; h &*= 0xBF58_476D_1CE4_E5B9
    h ^= h >> 27; h &*= 0x94D0_49BB_1331_11EB
    h ^= h >> 31
    return h
}
```

Value noise (`SeededIslands/ValueNoise.swift`), for tile coordinates `x, y ≥ 0` and a cell size `c`:

- lattice value `v(ix, iy) = Int(mapHash(seed, salt, ix, iy) >> 52)`, in 0…4095
- `ix = x / c`, `tx = (x % c) * 4096 / c`, and the same for y
- smoothstep `s(t) = t * t * (3 * 4096 - 2 * t) / (4096 * 4096)`
- `a = v00 + (v10 - v00) * sx / 4096`, `b = v01 + (v11 - v01) * sx / 4096`, `noise = a + (b - a) * sy / 4096`

Swift's `/` truncates toward zero on every platform, so negative intermediates are deterministic.

fBm: `fbm(x, y, salt, octaves) = Σ wᵢ · noise_cᵢ(x, y, salt + i) / Σ wᵢ`, in 0…4095.

| Field | Salt base | Octaves (cell, weight) |
|---|---|---|
| Coast | `0x15A0 + islandIndex` | (24, 8), (12, 4), (6, 2), (3, 1) |
| Mountain | `0x2B00 + islandIndex` | (16, 4), (8, 2), (4, 1) |
| Forest | `0x3C00 + islandIndex` | (12, 4), (6, 2), (3, 1) |

The noise seed for attempt `k` (D7) is `attemptSeed = mapHash(seed, 0x5EED, k, layoutCode * 64 + sizeCode * 8 + islandCount)`, with `layoutCode` 0 for single island and 1 for archipelago and `sizeCode` 0/1/2 for small/medium/large. A different size or island count gives a different map from the same seed. The world's own `seed` (simulation RNG, island names) stays the player's seed.

### D4. One island outline

An island blueprint is `(index, cx, cy, rx, ry)` in tile units. It is shaped in its own box: the tiles with `|x − cx| ≤ R` and `|y − cy| ≤ R`, where `R = (max(rx, ry) * 5 + 3) / 4` (1.25 × radius, rounded up). The box is clipped to the map, and the three outermost rows and columns of the map are always water.

1. **Raw mask.** With `dx = x − cx` and `dy = y − cy`, `q = (dx² · ry² + dy² · rx²) · 4096 / (rx² · ry²)` (Int64). The ellipse rim is 4096. The tile is land when `q ≤ 6400` and `2 · q < 6144 + 3 · (coast − 2048)`. For average noise this puts the coast at about 0.87 of the radius; low noise cuts bays and high noise pushes headlands out to the 1.25 bound.
2. **Smooth.** Two passes of 3×3 majority vote: a tile is land when at least 5 of the 9 tiles around and including it were land in the previous pass. Tiles outside the box count as water. Each pass reads a copy.
3. **Spurs and notches.** Up to 4 passes, each reading a copy. A land tile with at most 1 land tile among its 4 side neighbours becomes water. A water tile inside the box, not on its edge, with at least 3 land side neighbours becomes land. Stop early when a pass changes nothing.
4. **One landmass.** Keep the largest 4-connected land component. A tie goes to the component whose first tile in row-major order comes first. Other components become water, so no islet becomes an island of its own.
5. **No lakes.** Water tiles not 4-connected to the box edge become land, so every water tile is sea and ships never get stuck in a lake.
6. **Minimum size.** When fewer than `rx · ry · 3 / 2` land tiles remain (about 63% of the expected area), the attempt fails (D7).

The island is then stamped into the world grid. Stamps never overlap (D5).

### D5. Island placement

**Single island.** One blueprint, index 0: `cx = S/2 + j`, `cy = S/2 + j'`, with `j` and `j'` uniform in `−S/32 … S/32`, and `rx` and `ry` each uniform in `S·40/100 … S·46/100` (integer division; 38 to 44 tiles on Medium).

**Archipelago.** A `DeterministicRNG(seed: attemptSeed)` gives the values in this order: the home radii, then for each other island and each try `rx`, `ry`, `cx`, `cy`. "Uniform in `lo … hi`" is `lo + Int(rng.next() % UInt64(hi − lo + 1))`.

- The home island (index 0) sits exactly at `(S/2, S/2)`, so the map's centre tile is on it. That keeps the existing rules for the home island and the camera (`homeIslandID`, `centerCameraOnHomeTownCenter`) unchanged.
- Radii, as a percent of `S` and never below 20 tiles:

  | Islands | Home `rx`, `ry` | Others `rx`, `ry` |
  |---|---|---|
  | 3 | 15–18 | 11–14 |
  | 4 | 14–17 | 10–13 |
  | 5 | 13–16 | 9–12 |
  | 6 | 12–15 | 8–11 |
  | 7 | 11–13 | 7–9 |

  On Medium with 5 islands this gives a home island of 39–48 and others of 27–36, close to the classic 50×40 and 28–38.
- Other islands, index 1 to count − 1: each gets at most 200 tries. A try draws radii, computes `R` as in D4, and draws `cx` and `cy` uniform in `3 + 6 + R … S − 1 − 3 − 6 − R` (map border 3, sea margin 6). The try is accepted when, for every island placed before it, `(cx − cxⱼ)² + (cy − cyⱼ)² ≥ (R + Rⱼ + 10)²`. When 200 tries fail, the attempt fails.

Because each landmass lies inside its own 1.25 × radius disc, discs keep at least 10 tiles of water between them and stay at least 6 tiles from the map border, and lakes are filled, the sea is one connected body by construction. The validator still checks it (D7, check 7).

### D6. Terrain inside an island

For each stamped island, run a multi-source 8-neighbour BFS from water to get `dist`, the Chebyshev distance of each land tile to the nearest water, capped at 16.

- **Beach**: `dist ≤ 2`.
- **Mountain**: among tiles with `dist ≥ 5`, the first `land · 8 / 100` tiles in order of mountain noise (highest first), then `y`, then `x`. Since the noise is smooth, these form ranges and outcrops, not dots. If fewer tiles have `dist ≥ 5`, all of them become mountain.
- **Forest**: among the remaining tiles that are not beach, the first `land · 22 / 100` in order of forest noise (highest first), then `y`, then `x`.
- **Grass**: everything else.

`land` is the island's land tile count after D4. Shares are counted, not thresholded, so every island gets 8% mountain and 22% forest whatever the noise does. These two percentages, the coast constants in D4 step 1 and the radius table in D5 are the only tuning knobs. Tuning them must keep every guarantee in D7.

### D7. Construct, validate, retry, fall back

`World.newGame` with `map.style == .generated` runs:

```
for attempt in 0 ..< 8 {
    guard let terrain = SeededMapGenerator.terrain(layout, map, seed, attempt) else { continue } // D4.6 / D5 failure
    var world = generate(layout:seed:width:height:terrain:…)   // the existing pipeline, unchanged
    world.map = map; world.mapAttempt = attempt
    if MapValidator.failures(in: world).isEmpty { return world }
}
var world = newGame(layout:seed:…, map: .classic)   // classic fallback
world.map = map; world.mapAttempt = nil
return world
```

`MapValidator.failures(in:)` (`SeededIslands/MapValidator.swift`) returns a sorted list of `MapCheckFailure` values. An attempt passes when the list is empty:

1. **Island count**: `islands.count` is 1 for a single island, or `map.islandCount` for an archipelago.
2. **Home**: the map's centre tile lies on an island (archipelago only).
3. **One town center per island**: every island has exactly one town center, whoever owns it.
4. **Fair start**: every town center's `startArea(ofTownCenterAt:).isFair`: at least 150 grass, at most one quarter mountain, and a lumberjack hut site with at least 12 trees.
5. **Near mine site**: every town center has a mine site at most `starterMineRoadReach` (10) road tiles from its ring. The check is extracted from the early-return guard in `raiseStarterMineSite` into `World.hasNearMineSite(besideTownCenterAt:island:tileToIsland:)`, which both use.
6. **Port shore**: on a probe copy with every tech researched, there is a port anchor on the town center's island with `siteRejection(.port, at:, for: owner, tileToIsland:) == nil` and Chebyshev distance at most 40 from the town center's anchor.
7. **One sea**: all water tiles form one 4-connected component.

Bounds: at most 8 attempts. Each attempt does one terrain build (O(S²)) and one run of the existing pipeline. The fallback is the classic map, which the existing sweeps prove fair (`scenario: every start is fair across seeds`), so generation always ends and every start is fair. The property test (D13) requires that no seed in its range falls back. A fallback in the field is a quality bug, not a fairness bug.

Rivals: `seedRivals` takes a prefix of the other islands, so fewer islands seat fewer rivals. Today three islands on Hard give two rivals; `add-island-specialization` also keeps the colony island free, which leaves one. Generation must pass either way. The validator checks every town center whoever owns it, and the existing rule "start placement independent of difficulty" keeps positions the same whether rivals are on or off.

### D8. New Game dialog

All in `layoutSection` of `NewGameDialogView`, using `Picker` and the footnote `Text` style the section already uses:

- **Map** (`newGame.map`): a `.menu` picker below the layout picker with Classic, Small, Medium and Large. It is bound to `NewGameDialogViewModel.mapChoice` (`enum MapChoice { classic, small, medium, large }`, default `.medium`). Accessibility identifier `newGame.map`.
- **Islands** (`newGame.islands`): a `.menu` picker with 3 to 7, shown only when `layout == .archipelago`, `mapChoice != .classic` and the map is not locked. Default 5. Accessibility identifier `newGame.islands`. The numbers are verbatim `Text`, not catalog keys.
- **Hint**: a footnote under the Map picker, `newGame.mapHint`, or `newGame.mapScenarioHint` while the map is locked.
- **Scenario mode** locks the map: `isMapLocked = mode == .scenario`. The picker is disabled and shows Classic through a binding whose getter returns `.classic` while locked; the sandbox choice is kept. `commit()` in scenario mode stays exactly as today.
- **Sandbox commit** passes `map: mapSettings`: `.classic` for Classic, otherwise `.generated(size:, islandCount: layout == .archipelago ? islandCount : 1)`.
- **Seed default**: the dialog now opens, and resets on cancel, with `.random(captured:)`, rolled through `useRandomSeed()`, so a new game gets a new map. "Default" is still there and still means seed 0, so its text "Seed: 0 (same world every time)" stays true.

New catalog keys in `Packages/CityUI/Sources/CityUI/Resources/Localizable.xcstrings`, each with `de` marked `translated`:

| Key | en | de |
|---|---|---|
| `newGame.map` | Map | Karte |
| `newGame.mapClassic` | Classic | Klassisch |
| `newGame.mapSmall` | Small | Klein |
| `newGame.mapMedium` | Medium | Mittel |
| `newGame.mapLarge` | Large | Groß |
| `newGame.islands` | Islands | Inseln |
| `newGame.mapHint` | Classic is the same map in every game. Small, Medium and Large grow new islands from the seed. | Klassisch ist in jedem Spiel dieselbe Karte. Klein, Mittel und Groß lassen aus dem Seed neue Inseln wachsen. |
| `newGame.mapScenarioHint` | Scenarios are played on the classic map. | Szenarien werden auf der klassischen Karte gespielt. |

This is not a significant visual change in the sense of `CLAUDE.md`: no new screen or panel and no HUD layout change. Two pickers and a hint line go into an existing dialog section, built from the components that section already uses. The dialog has no `design/web` counterpart in `design/web/src/components/` to update; the implementer confirms that and writes "none" with the reason in the PR's `## Design system` section.

### D9. Seam for island profiles

`add-island-specialization` (PR #439) owns profiles. It adds `World.assignIslandProfiles()` in `World+IslandProfiles.swift`, called in `World.generate` after town centers, groves, mine sites and directives and before `seedRivals`. It reads the final terrain and the island list, may override the climate of the home and colony islands, and doesn't change terrain. This change adds no hook and no file of that name, so the two changes don't collide in either merge order.

The seam is the island list. A generated map hands `World.generate` terrain whose `IslandDetector` list has exactly the requested islands, each with a climate from the existing default rule (bounding-box centre in the north half → temperate, otherwise tropical). Profiles then attach to those islands exactly as they do on a classic map. `IslandBlueprint` carries no climate, so the generator never decides one.

The validator (D7) runs on the world `World.generate` returns, so it runs after profiles are assigned. Because profiles don't change terrain, none of the seven checks depends on them. If a later profile rule does change terrain, it is covered by the same retry.

If `add-island-specialization` merges first, the M1 implementer adds one test: a generated archipelago gets a profile on every island, and a colony island when it has at least three islands.

### D10. Rendering

Checked in `Packages/CityRender2D` and the CityUI map views. Nothing assumes 96 or 300 or a fixed island layout; every consumer reads `snapshot.mapWidth`, `mapHeight` and `terrainGrid`:

- `GroundBackdropMap`: one texel per tile, a 360×360 texture at Large. No change.
- `GroundMacroField`: a pixel buffer of `2(W+H) × (W+H)`, plus the scree buffer. At 360 that is 1440×720 RGBA ≈ 4.1 MB each, against 2.9 MB at 300. M1 task 5.4 measures its build time on the Large archipelago. No code change is expected.
- `TerrainTransitionMap` / `TerrainCorners`: all 14 corner masks of `grass-beach` and `beach-water` exist in `Resources/Kit.atlas`, including the diagonals t5 and t10, so any coast shape has a tile. D4 steps 3 and 5 remove one-tile spurs, notches and lakes anyway.
- `Culling`, `VisibleTiles`, ambient layers (birds, fish, sawdust, plaza crowd): use the snapshot size.
- `MinimapProjection` / `MinimapTerrainRaster` / `TVMapOverviewView`: size-generic, and the raster is `W × H`.
- Camera: starts on the home town center, and nothing clamps it to a fixed map.
- Title backdrop: `UITestSeed.townWorld` → classic single island, seed 0. Unchanged.

So M1 changes no renderer code. It adds one render test (task 5.3) and one measurement (task 5.4).

### D11. Persistence

`map` and `mapAttempt` are decoded with `decodeIfPresent`, defaulting to `.classic` and nil, following the "Saves without it decode…" pattern in `World.swift`. There is no `SaveFile.currentVersion` bump, because no existing field changes shape. Terrain is read from the save, never regenerated, so loading a save made before or after this change gives back the exact map. A Large archipelago adds about 44% terrain JSON against a 300×300 save.

### D12. Sweeps and regressions

- **Classic maps must not move.** In M1 every existing test that names tiles must pass without edits; a test that needs an edit means the classic presets changed, which is a bug. The full release sweeps on classic maps (`solvency`, `pacing`, `rivals`) must produce lines byte-identical to the last baseline. The orchestrator hands out the sweep slot; `SWEEP_SEEDS=1` smoke runs need no slot.
- **Generated maps get their own sweeps (M2).** Add `MAP_STYLE=generated` to the PlayerBot test support, so `World.newGame` gets `.generated(size: .medium, islandCount: 5)` (archipelago) or `.generated(size: .medium, islandCount: 1)` (single island). Rerun `pacing` (`midGamePacingAcrossSeeds`, `PACING_RETENTION=1`), `solvency` and `rivals` (`scenarioRivalsAreViableAcrossSeeds`). These count as regressions against the classic baseline of the same run:
  - median `merchantsAtTen` more than 15% below classic, or `heldShare` more than 0.10 below classic, for any difficulty and layout;
  - any solvency seed that passes on classic and fails on generated;
  - more than 3 of 60 rival viability lines failing beyond the classic count;
  - any seed in the property test that falls back to classic or fails a check.
- **Start-site sweep.** The M1 property test (D13) prints one `MAPGEN_SWEEP` line per world: layout, size, islands, seed, attempt, minimum grass, minimum hut-site trees, maximum mine road steps, minimum port distance. Its distribution is the start-site sweep the issue asks for.

### D13. Tests

New suites in `Packages/CityCore/Tests/CityCoreTests/`:

- `SeededMapGeneratorTests.swift`: determinism; outline shape (not an ellipse, has bays and headlands); size and count follow the settings; separation and one sea; no lakes or islets; shares; seed changes the map; two golden hashes.
- `MapValidatorTests.swift`: one test per check, on hand-made terrain that breaks it; retry and fallback through an injectable generator (`SeededMapGenerator.terrain` takes an internal `attempts` closure in tests).
- `GeneratedFairStartPropertyTests.swift`: the 200-seed property test (seeds 0 ..< 200, single island Medium and archipelago Medium with 5 islands), which asserts every check directly, not through `MapValidator`. Plus a 20-seed matrix over every size × island count. Both use `.serialized` arguments like `scenarioEveryStartIsFairAcrossSeeds`. If the debug run of the 200 archipelago seeds goes over 120 s on the dev Mac, keep seeds 0 ..< 50 in the default run and put the full 200 behind `MAPGEN_SWEEP=1`, run in release in CI's `rival-sweep` workflow. Either way, 200 seeds must pass before M1 merges, and the PR says which way it went.
- `MapSettingsPersistenceTests.swift`: round trip; a save fixture written on `main` before this change decodes as classic.
- In CityUI, `NewGameDialogTests.swift`: the dialog scenarios.
- In CityRender2D: every transition tile on 20 generated maps names an asset in the atlas.

Golden hashes are FNV-1a 64 over the terrain's raw values joined with `\n`, pinned after the first green run for (single island, Medium, seed 1) and (archipelago, Medium, 5 islands, seed 1). A generator change that moves them must update them in the same commit and say why.

`DeterminismFixture/main.swift` adds `generated: World.newGame(layout: .archipelago, seed: 0xC17D, map: .generated(size: .medium, islandCount: 5))` to its `Fixture`. That world runs the same tick count, so the macOS/Linux diff covers the generator.

## Risks / Trade-offs

- **Generation time.** Up to 8 runs of the existing pipeline. The grove probe copies the world for each candidate, so the slow path is real. Mitigation: D4 and D5 fail early, before the pipeline runs. M1 measures the Medium and Large archipelago in release on the dev Mac (task 3.6). If the worst case of the 200 seeds goes over 1.5 s, M2 moves `commit()` off the main actor behind the existing disabled Start button. No new UI.
- **Balance drift.** Generated islands differ from the classic ones, with more forest (22% against about 16%) and mountain ranges instead of dots. Mitigation: shares are counted, not thresholded; the fair-start floor is the same rule; the M2 sweeps gate a release.
- **Save size** at Large. Accepted; see D11.
- **A default the player didn't pick.** New Game now defaults to a generated Medium map and a random seed. Players who want the old map pick Classic; seed 0 and Classic together give exactly today's map.
- **Classic fallback hides a bad seed.** `mapAttempt == nil` with a generated style makes it visible in a save and in tests. A later change may show it to the player.

## Migration Plan

No data migration. Old saves decode as Classic (D11). Rollback is to revert the change: generated saves still load after a rollback, because their terrain is stored and the unknown `map` key is ignored by the old decoder. Check that in task 4.3.

## Open Questions

None blocking. Generated maps for campaign chapters and scenarios are left to a follow-up (tasks, M3).
