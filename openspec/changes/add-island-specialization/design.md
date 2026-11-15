## Context

See proposal.md for the why. The state of the code this design builds on:

- `IslandDetector` (`WorldLayout.swift`) computes the `Island` list once, in `World.generate` (`World+Fixture.swift`). Nothing recomputes it later, so a value stored on `Island` is stable for the whole game. `Island` already decodes a missing `name` with a default; the profile follows that pattern.
- Climate today: an island whose bounding-box centre row is above the map's middle row is `temperate`, otherwise `tropical`. On the current 300×300 archipelago the two northern islands are temperate and the central (home) island and the two southern islands are tropical. Nothing reads climate outside `WorldLayout.swift` and its tests; no renderer uses it.
- Home island: `World.homeIslandID(in:)`, the island under the map's centre tile. Rivals: `World.seedRivals` seats `difficulty.rivalCount` (1 / 2 / 3) rivals on the other islands, largest first (`otherIslandsBySize`). Every island that fits one gets a town center in `seedTownCenters`, before rivals are seated; the ones no rival takes stay the player's.
- Crops: `farm` (food), `grain-farm` (grain), `sheep-farm` (wool) and the four culture gardens `hop-garden`, `vineyard`, `tea-garden`, `coffee-grove`. Every crop building is a recipe producer with no inputs. `Systems.swift` `runProductionSystem` is the only place that compares progress with `recipe.cycleTicks`.
- Rivals build only houses, roads, lumberjack huts, foresters, sawmills, farms and warehouses, so the only crop they touch is the farm.
- Merchants need food, planks, bread, tools, cloth and their culture's luxury (`HouseTier.needs(in:)`). The luxury good (beer, wine, tea, coffee) is made from the garden's raw crop by the culture's producer.
- The town market's terms come from each good's pack entry (`Good.marketTerms`, `Good.marketPrice`); luxuries have a buy limit of 0 today.
- The PlayerBot's mid-game kit (`Tests/CityCoreTests/PlayerBot+MidGame.swift`) builds two luxury gardens and a producer at home. It never builds ports or ships.

## Goals / Non-Goals

**Goals:**

- In an archipelago game the player's merchants need a good the home island cannot grow, and a second island the player already owns can grow it.
- Food, wood and planks never depend on the profile, for the player or a rival. Single-island games and old saves play exactly as before.
- Everything a profile does is readable from surfaces that exist: the status pill, the stocks tray, the count capsule, the inspector and the rejection banner.
- M1 ships alone, with no new art and no new panel.

**Non-Goals:**

- Per-tile fertility (#261's noise map). The profile is per island in M1; per-tile soil comes with its overlay in M3.
- A profile overlay, a new-game profile preview or any new panel: design-gated, M3.
- Changing terrain. Forest, mountains and town center sites stay exactly what the generators and the fair-start rules make today.
- A PlayerBot that colonises: M2.

## Decisions

### D1. The profile is a small value on `Island`

New file `Packages/CityCore/Sources/CityCore/IslandProfile.swift`:

```swift
public enum CropFamily: String, Codable, Sendable, CaseIterable { case field, grain, pasture, garden }
public enum ForestRichness: String, Codable, Sendable { case sparse, fair, rich }
public struct IslandProfile: Hashable, Codable, Sendable {
    public let field: Int       // percent; farm
    public let grain: Int       // percent; grain farm
    public let pasture: Int     // percent; sheep farm
    public let everyGarden: Bool // true: every garden grows at 100 whatever its climate
    public let hasOre: Bool
    public let forest: ForestRichness
    public static let complete = IslandProfile(field: 100, grain: 100, pasture: 100, everyGarden: true, hasOre: true, forest: .fair)
}
```

`Island` gains `public let profile: IslandProfile`. The yield of a crop kind on an island is `World.soilYield(of: kind, on: island) -> Int`: field, grain and pasture read their field; a garden yields 100 when `everyGarden` is true or the garden's climate equals the island's climate, else 0. A building kind with no `cropFamily` has no yield (nil).

Explicit fields, not a `[CropFamily: Int]` dictionary: a dictionary encodes in hash order, and saves must re-encode byte-identically. Alternative considered: a per-tile fertility grid (#261). Rejected for M1: it needs the overlay to be readable, a new save array of 90,000 entries on the archipelago, and new fair-start rules.

### D2. Crop families and garden climates are content

Building items in the packs get two fields, read by GameDataGen and emitted on `BuildingKind`:

| Building | `cropFamily` | `climate` |
|---|---|---|
| farm | field | — |
| grain-farm | grain | — |
| sheep-farm | pasture | — |
| hop-garden | garden | temperate |
| vineyard | garden | tropical |
| tea-garden | garden | tropical |
| coffee-grove | garden | tropical |

A new singleton item, modelled on `kind: Logistics`, in `packs/core.yaml`:

```yaml
  # Island resource profiles. Spec: world-terrain / Island resource profile.
  - kind: IslandProfiles
    id: island-profiles
    climates:
      temperate: { field: 100, grain: 125, pasture: 125 }
      tropical:  { field: 100, grain: 75,  pasture: 75 }
    soilSteps: [-25, 0, 25]     # seeded offset for grain and pasture on islands other than home
    yieldRange: [50, 150]       # clamp after the offset
    oreChancePercent: 50        # islands other than home and colony
    forest: { richAtPercent: 18, fairAtPercent: 10 }
    luxuryImport: { buy: 12, pricePercent: 200 }
```

GameDataGen changes: `pack.schema.json` (the kind enum, an `if/then` block for `IslandProfiles`, the two building fields with `cropFamily` in `field|grain|pasture|garden` and `climate` in `temperate|tropical`), `Loader.swift`, `Model.swift`, `SwiftEmitter.swift`; the generated file is `Generated/IslandProfiles+Generated.swift` with `enum IslandProfilesCatalog`. The validator rejects a `garden` without a `climate` and a `climate` on a non-garden.

Alternative considered: hard-coding the table in Swift. Rejected: the project keeps balance numbers in packs, and a sweep-driven retune should be a one-line YAML edit.

### D3. How a profile is made

`World.assignIslandProfiles()` runs in `World.generate` right after `world.culture = culture` and before `seedRivals`, so it sees the final terrain (town centers, groves, mine sites and campaign directives done) and the player's culture.

Single-island layout: every island gets `IslandProfile.complete` with its forest label (below), and keeps its climate.

Archipelago layout:

1. **Home** is `homeIslandID(in:)`. **Colony** is the smallest island other than home that holds a town center (fewest tiles, ties by lower `IslandID`); none when no such island exists.
2. **Luxury climate** `L` is the climate of the player's culture's garden (`culture.luxuryChain.garden.climate`). Home's climate becomes the other climate; the colony's becomes `L`; every other island keeps the north/south rule. Climate is set by rebuilding the `Island` value; `IslandID`, name, bounds and tile count never change.
3. **Yields.** Home: field, grain and pasture 100, `everyGarden` false. Every other island: its climate's row of the table, then grain and pasture each add `soilSteps[hash(seed, id, salt) % 3]` (salt 1 for grain, 2 for pasture) and clamp to `yieldRange`; field stays 100; `everyGarden` false.
4. **Ore.** Home and colony: true. Others: `hash(seed, id, 3) % 100 < oreChancePercent`.
5. **Forest.** For every island: `forestTiles × 100 / tileCount` at assignment time; at least `richAtPercent` is rich, at least `fairAtPercent` is fair, below is sparse. A label, no rule reads it in M1.

`hash` is the SplitMix mixer `IslandNameTable` already uses, over `(seed, islandID, salt)`. It never draws from the world RNG, so the RNG stream, and every replay that does not touch a crop, stays identical.

Results on today's map with the default Northern European culture: home (centre) becomes tropical, so hops cannot grow there; the smallest island (south-west, 28×28) is the colony and becomes temperate; rivals sit on the two northern islands and the south-east one as before. For the three other cultures, home becomes temperate and the colony tropical.

Alternatives considered: (a) keep geographic climate and forbid luxury gardens on home by rule. Rejected: the brief asks for climate to drive it, and a rule with no in-world reason reads as arbitrary. (b) Make the home's luxury yield 50% instead of 0. Rejected: a slow garden still removes any reason to sail. (c) Pick the colony as the largest free island. Rejected: which islands are free depends on the rival count, so the profile would depend on difficulty; the smallest island never does, because rivals fill from the largest.

### D4. Soil scales a crop's cycle

In `runProductionSystem`, the completion test becomes `progress.ticksThisCycle >= World.cropCycle(recipe.cycleTicks, yield:)` for buildings whose kind has a `cropFamily`:

`cropCycle(c, yield: y) = (c × 100 + y − 1) / y` for `y > 0` (integer division, rounds up). At 100 the cycle is unchanged, so every farm everywhere, and every crop on single-island maps and old saves, keeps its exact timing. Examples for the 40-tick crops: 125% → 32, 75% → 54, 50% → 80, 150% → 27. A yield of 0 never completes a cycle (placement prevents it; this is a guard).

The island map is fetched once per production pass with `tileToIslandMap()` (cached by `IslandMapCache`), only when at least one crop producer is operational. Winter slowing, blight and workshop bonuses keep applying to progress exactly as today.

Alternative considered: a fractional progress accumulator in `ProductionProgress`. Rejected: it adds save state for the same result.

### D5. Placement rules

`PlacementRejection` gains `.wrongClimate(Climate)` (the climate the crop needs; code `wrong_climate`) and `.noOre` (code `no_ore`). In `World+Placement.swift` they are checked after `wrongCulture` and before materials, for every owner: a garden whose yield on the anchor's island is 0 is rejected with `.wrongClimate(kind.climate)`, and a mine on an island with `hasOre == false` with `.noOre`. The mine's existing `needsTerrain(.mountain)` check runs first, so the player learns about rock before ore. Rivals never build gardens or mines, so their placement is unaffected.

### D6. The luxury import

`World.importsLuxury` is true when the layout is archipelago and the player's culture's garden yields 0 on the home island. While it is true, the town market lists the culture's luxury good with a buy limit of `luxuryImport.buy` (12) per season at `basePrice × pricePercent / 100` ($32 for every luxury today); its sell terms stay the pack's. Everything else about buying (fill order, ledger, limits per player, `marketTraded`) is the existing `marketBuy`.

Implementation: world-level `marketTerms(for:)` and `marketPrice(_:_:)` that wrap the good's own, used by `marketQuotes`, `marketLeft` and `applyMarketBuy`; `MarketLedger.left` takes the limit instead of reading `good.marketTerms`. Rival market trades keep the pack terms.

Sizing: merchants eat 1 luxury per 8 residents per 100 ticks, so one full merchant house eats 6 a season; 12 a season holds two houses (16 merchants). One merchant house pays $32 tax per 50 ticks, $384 a season, against $192 for its imported luxury, so the import is worth it but caps the merchant quarter. The no-loop rule still holds: $32 to buy is above every price the luxury sells for ($8 at the market, $16 by caravan; rivals do not trade luxuries).

Alternatives considered: (a) no import. Rejected: a player who never sails could never see a merchant, and the PlayerBot pacing sweep would lose every archipelago merchant. (b) Import the raw crop. Rejected: two goods and a producer between the market and the need make the bridge too weak to notice.

### D7. Rivals leave the colony free

`seedRivals` seats rivals from `otherIslandsBySize(home:)` with the colony removed. On today's five-island map the colony is the smallest island, which no rival takes at any difficulty, so seats do not change. On a map with fewer than `rivalCount + 2` islands, fewer rivals are seated; `importsLuxury` still gives the player their merchants.

Alternative considered: let a rival sit on the colony. Rejected: the player could then never grow their luxury, and the colony's whole point is that it is theirs.

### D8. Text on existing surfaces (English / German)

| Key | English | German | Where |
|---|---|---|---|
| `hud.island.temperate` | Temperate island | Gemäßigte Insel | status pill caption above the island name |
| `hud.island.tropical` | Tropical island | Tropische Insel | status pill caption |
| `profile.complete` | Every crop grows here | Hier gedeiht jede Feldfrucht | stocks tray, line under the header |
| `profile.soil` | Grain %1$d%% · Wool %2$d%% | Getreide %1$d %% · Wolle %2$d %% | stocks tray line |
| `profile.luxury.grows` | %@: can grow | %@: Anbau möglich | stocks tray line, the player's raw luxury |
| `profile.luxury.wontGrow` | %@: can't grow | %@: kein Anbau | stocks tray line |
| `profile.ore.yes` | Ore | Erz | stocks tray line |
| `profile.ore.no` | No ore | Kein Erz | stocks tray line |
| `profile.forest.rich` | Rich forest | Reicher Wald | stocks tray line |
| `profile.forest.fair` | Some forest | Etwas Wald | stocks tray line |
| `profile.forest.sparse` | Sparse forest | Wenig Wald | stocks tray line |
| `aoe.soil` | Soil %d%% | Boden %d %% | count capsule over a crop ghost |
| `inspector.soil` | Soil here: %d%% | Boden hier: %d %% | inspector of a crop building |
| `placement.wrongClimate` | %1$@ needs a %2$@ island. | %1$@ braucht eine %2$@ Insel. | rejection banner |
| `climate.needs.temperate` | temperate | gemäßigte | argument of `placement.wrongClimate` |
| `climate.needs.tropical` | tropical | tropische | argument of `placement.wrongClimate` |
| `placement.noOre` | There is no ore under this island. | Unter dieser Insel liegt kein Erz. | rejection banner |

The tray line joins its parts with " · ": `profile.complete` alone for a complete profile, else soil, luxury, ore, forest. The capsule tone is neutral at 100% and above and amber (`.low`) below. Only player-visible text changes; no view gains a new element except the tray's one `Text` line, which uses the header's font and colour. The pill caption is longer than "Island" ("Gemäßigte Insel", 15 characters); the stat already has a line limit and a `minimumScaleFactor`, and M1 checks the phone layout in the existing pill layout tests rather than changing the layout. Every key is marked `translated` in German; `make l10n-check` must pass.

Alternative considered: putting the climate into the name ("Linden, tropical"). Rejected: the name is also the rival's town name and the stocks tray header.

### D9. Snapshot

`IslandSummary` gains `climate: Climate` and `profile: IslandProfile`; `WorldSnapshot` gains `importsLuxury: Bool`. The UI reads only the snapshot and `World.soilYield` (already public through `GameSession.world`).

### D10. Saves

`Island.init(from:)` decodes `profile` with `decodeIfPresent` and falls back to `IslandProfile.complete`. Every save written before this change therefore loads with every crop at 100%, every garden allowed and ore everywhere: nothing an old town built stalls or becomes unplaceable, and an old save's `importsLuxury` is false. No version bump: the field is additive (the same pattern as `Island.name` and `MarketLedger`), and other changes in flight tonight may bump `SaveFile.currentVersion`; a bump here would collide for nothing.

### D11. PlayerBot

`PlayerBot+MidGame.swift`: when `world.importsLuxury`, the kit drops its luxury garden and producer steps, and with `tradesAtMarket` it buys `min(8, marketLeft(luxury, .bought))` of the luxury at its town center whenever its island holds fewer than 6. Without the market the bot gets no luxury in archipelago games, which the no-market arm records. Colonising is M2.

### D12. Balance sweeps before release

Baseline: run each sweep on `origin/main` at the merge base, then on the branch, with `scripts/sweeps/run-release-sweeps.sh` (the orchestrator hands out the single sweep slot; `SWEEP_SEEDS=1` smoke runs do not need it).

| Sweep | Expected | Regression |
|---|---|---|
| `solvency` (`SOLVENCY_SWEEP`, `GUIDE_SWEEP`) | Every line byte-identical: the first hour builds no garden, mine, grain farm or sheep farm off home, and home yields 100 | any line differs, or exit status ≠ 0 |
| `rivals` (`RIVAL_SWEEP`, 60 lines) | Every line byte-identical: rivals' seats, farms and RNG are untouched | any line differs, or exit status ≠ 0 |
| `pacing` (`PACING_SWEEP`), single-island lines | byte-identical | any line differs |
| `pacing`, archipelago lines, market arm | first merchant still reached; `heldShare` and `meanLate` may drop (the bot does not colonise) and are recorded in the PR, not gated | per difficulty: a game whose baseline reached a first merchant reaches none by year 20; or the median year of the first merchant rises by more than 1.0; or the median `merchantsAtTen` falls below 8 where the baseline median was 8 or more |
| `FairStartSiteTests` (normal suite, seeds 0–49) | pass: terrain is unchanged | any failure |

The events sweeps (`guidedHardStartWithFireSeason`, `forcedFireFirstHour`) do not need a rerun: this change touches no event.

### D13. Milestones

- **M1 (tonight):** D1–D11, tests, sweeps of D12.
- **M2:** campaign `TerrainDirective` cases `soil(IslandRef, CropFamily, percent)`, `noOre(IslandRef)` and `climate(IslandRef, Climate)`, applied after D3 (for Hard Ground 1 "poor soil on the home island", Merchant Sea 1 "the second island has the good soil", Merchant Sea 2 "no ore under home soil"); a PlayerBot that builds a port on the colony, grows its luxury there and runs a route home, after which `heldShare` on archipelago must return to within 0.10 of the pre-change baseline.
- **M3 (design-gated):** per-tile fertility from #261 (70–130% under a field's footprint), its overlay on the #241 canvas, the profile in the new-game dialog and on the minimap. Each needs a Claude Design canvas before code.

### Determinism and the framework-free invariant

Profiles are a pure function of the terrain after generation, the island list, the seed and the culture, computed with integer math and the existing SplitMix mixer, in `IslandID` order. No world RNG draw is added. The yield formula is integer division. The profile has fixed fields, so a save re-encodes byte-identically. Nothing new imports a framework: `IslandProfile.swift` uses Swift standard library types only, and `CityCore` keeps building on Linux.

## Risks / Trade-offs

- [Archipelago merchants get harder while the audit says merchants do not hold] → the import keeps two merchant houses possible without sailing; the colony scales past that. D12 gates the first merchant and merchants at year 10.
- [The home climate depends on the player's culture, which a player may find odd when comparing two games] → the pill caption names the climate in every game, and the rejection banner says what the crop needs.
- [A future generator makes fewer than `rivalCount + 2` islands] → D7 seats fewer rivals and the import keeps merchants reachable; the random-maps work is told (shared notes).
- [The Guild Town scenario played on an archipelago needs 30 merchants] → the import gives 16; the colony gives the rest. Its layout is the player's choice, and single-island stays unchanged.
- [Tests that compare encoded saves byte for byte change because `Island` gains a field] → regenerate those expectations in the same commit as the field, and say so in the commit body.
- [German declension in `placement.wrongClimate`] → the climate argument has its own `climate.needs.*` keys inflected for "eine … Insel".

## Migration Plan

Additive. Old saves load with complete profiles (D10). Rollback: revert the change; saves written with it still decode on the old build, because a synthesized decoder ignores unknown keys (`Island`'s decoder reads named keys only).
