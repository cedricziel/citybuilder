## Context

The renderer currently has a 1:1 mapping between terrain kinds (`TerrainType`) and sprite PNGs: `terrain-mountain` → `terrain-mountain.png`. Same for non-shore buildings: `building-road` → `building-road.png`. When a snapshot exposes hundreds of mountain tiles or a long road, every tile pulls the same texture, so the eye reads identical clones across the surface.

The implementation that ships variants under commit `22d1f7f` (already on `main`) adds:
- A second axis to the asset grammar: per-kind art *variants*, distinct from animation *frames* and shore *orientations*. Variant 0 keeps the canonical filename (no rename); variants 1..N-1 use a `-vN` suffix.
- A deterministic per-tile selector in `SpriteAtlas` that picks a variant from the tile's `(x, y)` coordinate.
- Tables `terrainVariantCounts` and `buildingVariantCounts` declaring how many variants each kind ships.

This design records *why* those choices are the right shape and what invariants future variant kinds must preserve.

## Goals / Non-Goals

**Goals:**
- Formalize a path that scales: adding "4 variants of forest" later is a table edit + new PNGs, not a renderer overhaul.
- Preserve replay/snapshot determinism — the same tile must render the same variant on every run, every device, every replay.
- Keep `assertCatalogComplete()` authoritative: a missing variant PNG fails the debug check the same way a missing base PNG does.
- Stay backwards compatible: every existing PNG keeps its name and meaning. Kinds with no variant table entry render exactly as before.
- Preserve the framework-free invariant for CityCore — this change lives entirely inside CityRender2D and the procedural generator; the simulation is untouched.

**Non-Goals:**
- Building rotations (e.g., houses facing four ways). The variant axis is purely cosmetic; a placed building still has one orientation as defined by `buildings-and-construction`.
- Animated variants. Each variant is a single PNG (animation frames stack independently on top, if/when a kind opts into both).
- Hand-authored variant overrides via a config file. The variant table lives in code so the renderer can use it at the type system level.
- Save-format changes. Variant selection is derived; never stored.

## Decisions

### D1 — `-vN` suffix vs separate folders or JSON manifest
Chosen: `-vN` suffix on the existing filename grammar (`terrain-mountain-v1.png`, `building-road-v2.png`).

Alternatives considered:
- Subfolder per kind (`Terrain.atlas/mountain/v1.png`): would force a new atlas-folder convention and break the flat-routing table that `SpriteAtlasRouting.atlasName(for:)` relies on.
- Sidecar JSON manifest mapping kind → variant list: adds a parsing step at startup and a new failure mode (manifest desync). The naming grammar is already the registry.

Trade-off: the suffix needs `<frame>` to *follow* `<variant>` if a kind ever ships both — the grammar enforces `<variant>` before `<state>` and `<frame>`. Today no kind opts into both, so this stays theoretical.

### D2 — Variant 0 uses the canonical stem (no `-v0`)
Chosen: the canonical sprite stays canonical (`terrain-mountain.png`, not `terrain-mountain-v0.png`).

Rationale: zero rename churn. Every existing PNG, test fixture, and screenshot reference keeps working. Code that hardcodes "the mountain sprite" still resolves. The cost is one minor irregularity in the grammar (variant 0 is implicit), which is easier to explain than renaming every existing asset.

Alternative considered: always-suffix (`-v0` mandatory). Cleaner grammar but a wide-radius rename of bundled assets, tests, and reconciler fixtures. Not worth it for a single irregularity.

### D3 — Deterministic coord hash vs stored selection vs RNG
Chosen: `variantIndex(coord:count:)` is a pure function of `(coord.x, coord.y, count)` using a splitmix-style 32-bit mixing function.

Rationale: variant must be a property of the tile's *position*, not of a tile *event* or per-run draw. If we used the world RNG, two tiles at the same coord across replays could disagree (because the RNG advances based on simulation activity). If we stored the variant in the save, every existing save would need a migration *and* the schema would carry purely cosmetic data.

The mix is splitmix-shaped (`x * 0x9E3779B1 + y * 0x6D2B79F5; xor-shift; multiply 0x7FEB352D; xor-shift`) — cheap (no allocations, single-cycle ops), produces visually well-mixed indices across a 2D grid, and is stable across architectures.

Determinism is preserved: variant selection is a pure function of the tile coord, so two simulations producing equal `World` values also produce equal rendered scenes.

### D4 — Per-kind variant-count tables in code
Chosen: `terrainVariantCounts: [TerrainType: Int]` and `buildingVariantCounts: [BuildingKind: Int]` as `public static let` constants on `SpriteAtlas`.

Rationale: variant counts are renderer-facing config, not simulation data. Keeping them in the same type that does the lookup means the type system catches missing entries (no string-typed kinds), and the test suite can pin the counts as a compile-time-stable inventory.

Alternative considered: derive the count by scanning the atlas at startup ("how many `terrain-mountain-v*` PNGs are there?"). Rejected because it makes the catalog non-deterministic — an extra PNG accidentally bundled would change behavior silently. Explicit table = explicit contract.

### D5 — Variant-aware lookup goes through a new entry point
Chosen: add `terrainTextureOrPlaceholder(for:coord:)` / `buildingTextureOrPlaceholder(for:coord:)` *alongside* the existing `terrainTexture(for:)` / `buildingTexture(for:)`. Old methods stay; the scene factory calls the new ones with the spec's coord.

Rationale: the existing `buildingTexture(for:)` is also used by the catalog enumeration (which has no coord) and by older code paths. Adding rather than replacing keeps those call sites correct (they should resolve the canonical stem, variant 0) while letting the new factory path use the variant-aware lookup.

### D6 — Ghost preview matches placement
Chosen: the ghost-preview path in `IsoWorldScene` uses the same variant-aware lookup as the placement path, keyed on `ghost.tile`.

Rationale: if the ghost shows a clean cobble road and the placed tile is mossy variant v3, players will read it as a bug. Picking the same coord through the same selector solves this with zero state.

## Risks / Trade-offs

- **[Grammar slot ordering ambiguity once a kind opts into both `<variant>` and `<frame>`]** → The grammar fixes the order: `<kind>-<variant>-<state>-<frame>`. Today no kind exercises this, but the spec scenario "Variant slot precedes state and frame" guards against drift. Generator and atlas catalog both produce names in that order.
- **[Variant 0's implicit form vs explicit suffix is a special case in the parser]** → Resolved by `variantAssetName(stem:variant:)` doing the canonicalization once. Every other call site reads from that helper, so the rule lives in one place.
- **[A future second variant axis (e.g., seasonal skins) would collide with `-vN`]** → Out of scope. If it ever lands, the grammar would need a second namespaced suffix (`-sN` for season?) and a new combining rule. Today, the spec rules out additional suffixes.
- **[Adding a variant for a kind already in the atlas requires bumping the table AND shipping the PNG together]** → The debug-build `assertCatalogComplete()` check enforces this — bumping the count without the PNG, or vice versa, fails fast. The catalog presence test is the safety net.
- **[Replay determinism could regress if someone introduces a variant lookup that reads from a non-coord source]** → A spec scenario pins this: same `(coord, count)` always returns the same index. Any future selector replacement is a spec change.

## Determinism Preservation

`World` byte-equality under replay is not affected:
- Variant selection is renderer-only (lives in CityRender2D, never touches CityCore).
- The selector is a pure function — same inputs, same output, no shared state.
- No new value is added to `World`, `WorldSnapshot`, `SpriteSpec`, or the save format. Two simulations producing equal `World` values produce equal sprite specs, which the selector renders identically.

## Migration Plan

The implementation already shipped (commit `22d1f7f` on `main`). This change captures the spec; no code migration is needed. Archive flow:
1. Spec delta lands under `openspec/specs/sprite-asset-pipeline/spec.md` after `/opsx:archive`.
2. Test coverage check (`scripts/check-scenario-coverage.swift`) sees the new scenarios and requires corresponding `@Test` cases in `CityRender2DTests` — those tests are the verification of the shipped behavior.
3. No data migration, no save bump, no asset rename.

Rollback: revert commit `22d1f7f` plus the spec delta. The canonical `terrain-mountain.png` and `building-road.png` PNGs would revert to their pre-change content; variant PNGs would be removed.

## Open Questions

- Should `forest` also opt in to variants? Three trees-on-grass clones are visible in current screenshots. Out of scope for this proposal — would land as a follow-up table bump + new PNGs.
- Should the variant count be exposed in a future debug HUD (e.g., "Mountain v2") for art QA? Not required by any current spec; would be a tooling-only addition.
