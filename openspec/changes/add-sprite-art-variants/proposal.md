## Why

A long line of mountain tiles or a stretch of road currently reads as the same PNG stamped over and over — visually flat. The implementation that adds per-tile art variants (multiple PNGs per kind, picked deterministically by tile coord) has already shipped on `main`, but the `sprite-asset-pipeline` spec's naming grammar still only allows `terrain-<kind>[-<frame>].png` / `building-<kind>[-<state>][-<frame>].png`. This proposal formalizes the new `-vN` slot in the grammar so the spec stays the source of truth, the catalog presence check has a contract to enforce, and future variant kinds extend a table rather than ad-hoc code.

## What Changes

- Extend the sprite-asset-pipeline naming grammar with a per-tile `-vN` variant suffix: `terrain-<kind>[-vN][-<frame>].png` and `building-<kind>[-vN][-<state>][-<frame>].png`. Variant 0 omits the suffix so the canonical stem keeps its current meaning (no rename of existing PNGs).
- Add a per-kind variant-count table for terrain and building kinds. Mountain ships 4 variants, road ships 4 variants. Kinds not listed in the table render the canonical single sprite (no behavior change).
- Add a deterministic tile-coord variant selector: same `(coord, count)` always picks the same variant index across runs, snapshots, replays, and renderer reconciliation.
- Catalog presence (`assertCatalogComplete()`) MUST list every declared variant so a missing variant PNG fails the debug-build check.
- Document that the ghost-preview path uses the same variant lookup so the preview at a tile matches what gets placed.

Not changing: animation-frame grammar (`-<frame>`), shore-orientation grammar (`-<orientation>`), atlas routing, or any save format. Variant selection is a pure function of the tile coord, never a stored field.

## Capabilities

### New Capabilities
<!-- none -->

### Modified Capabilities
- `sprite-asset-pipeline`: extends the terrain and building naming grammars with the `-vN` variant suffix; adds a "per-tile art variants" requirement covering the variant-count registry, the deterministic-coord-hash selection rule, and catalog presence enforcement for variant assets.

## Impact

- **Code already on `main`** (commit `22d1f7f`):
  - `Packages/CityRender2D/Sources/CityRender2D/SpriteAtlas.swift` — `terrainVariantCounts` / `buildingVariantCounts` tables, `variantIndex(coord:count:)`, `variantAssetName(stem:variant:)`, `terrainTextureOrPlaceholder(for:coord:)`, `buildingTextureOrPlaceholder(for:coord:)`, variant entries in `catalogSpriteNames`.
  - `Packages/CityRender2D/Sources/CityRender2D/SceneNodeFactories.swift` — `makeTerrainNode` / `makeBuildingNode` now thread `spec.coord` through the texture lookup.
  - `Packages/CityRender2D/Sources/CityRender2D/IsoWorldScene.swift` — ghost preview uses the variant-aware lookup so preview matches placement.
  - `scripts/generate-sprites.swift` — `mountainSprite(variant:)` and `roadSprite(variant:)` plus a write loop that emits `terrain-mountain-v1..v3.png` and `building-road-v1..v3.png` alongside the canonical names.
- **Asset count**: `Resources/Terrain.atlas/` gains 3 PNGs, `Resources/Buildings.atlas/` gains 3 PNGs.
- **No save-format change**: variant selection is derived from the tile coord, never stored.
- **No new build-time tool dependencies**: still Swift + xcodegen + swiftlint + swiftformat as before. The procedural generator is the same script that already runs.
- **Tests**: `CityRender2D` test suite (93 tests) passes against the shipped implementation. Spec scenarios will be added in `specs/sprite-asset-pipeline/spec.md` to cover the determinism contract and the catalog enforcement of variant assets.
