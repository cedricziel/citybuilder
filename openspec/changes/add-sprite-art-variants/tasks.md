## 1. Implementation (already shipped in commit 22d1f7f — verify, don't re-do)

- [ ] 1.1 Verify `SpriteAtlas.terrainVariantCounts` declares `.mountain = 4` and `SpriteAtlas.buildingVariantCounts` declares `.road = 4`
- [ ] 1.2 Verify `SpriteAtlas.variantIndex(coord:count:)` returns 0 for `count == 1` and a value in `0..<count` otherwise
- [ ] 1.3 Verify `SpriteAtlas.variantAssetName(stem:variant:)` returns the canonical stem for variant 0 and `<stem>-vN` for variant > 0
- [ ] 1.4 Verify `SpriteAtlas.terrainTextureOrPlaceholder(for:coord:)` and `SpriteAtlas.buildingTextureOrPlaceholder(for:coord:)` resolve via the variant index
- [ ] 1.5 Verify `catalogSpriteNames` enumerates every declared variant entry (mountain v1..v3, road v1..v3)
- [ ] 1.6 Verify `SceneNodeFactories.makeTerrainNode(kind:coord:)` and `makeBuildingNode(for:)` thread `spec.coord` through the variant-aware lookup
- [ ] 1.7 Verify `IsoWorldScene.reconcileGhost()` uses `buildingTextureOrPlaceholder(for:coord:)` keyed on `ghost.tile`
- [ ] 1.8 Verify the procedural generator emits `terrain-mountain-v1.png`..`-v3.png` and `building-road-v1.png`..`-v3.png` alongside the canonical PNGs
- [ ] 1.9 Confirm `Resources/Terrain.atlas/` and `Resources/Buildings.atlas/` contain the six new variant PNGs

## 2. Spec scenario coverage (new test work — TDD style)

- [ ] 2.1 Add `@Test("scenario: variant slot accepted for terrain")` in `SpriteNameTests` validating `terrain-mountain-v2` passes name validation
- [ ] 2.2 Add `@Test("scenario: variant slot accepted for land-only building")` in `SpriteNameTests` validating `building-road-v3` passes name validation
- [ ] 2.3 Add `@Test("scenario: variant slot rejected on shore building")` in `SpriteNameTests` validating `building-port-v1-n` fails validation
- [ ] 2.4 Add `@Test("scenario: mountain ships four art variants")` in `SpriteAtlasLayoutTests` or new `SpriteVariantTests` enumerating the catalog and asserting all four mountain stems are present
- [ ] 2.5 Add `@Test("scenario: road ships four art variants")` asserting all four road stems are present in the catalog
- [ ] 2.6 Add `@Test("scenario: variant selection is a pure function of coord and count")` calling `variantIndex` twice and asserting equality
- [ ] 2.7 Add `@Test("scenario: variant selection is in-range")` calling `variantIndex` for a sample grid and asserting the result is in `0..<count`
- [ ] 2.8 Add `@Test("scenario: variant zero when count is one")` asserting `variantIndex(coord:count:)` returns `0` when `count == 1`
- [ ] 2.9 Add `@Test("scenario: distinct coords map across the full variant range")` iterating a 16×16 region with `count=4` and asserting every index appears at least once
- [ ] 2.10 Add `@Test("scenario: missing variant png fails the debug catalog check")` constructing the catalog with a deliberately missing variant entry and asserting `missingSprites` flags it
- [ ] 2.11 Add `@Test("scenario: complete variant inventory passes the debug catalog check")` asserting `missingSprites(in: catalogSpriteNames)` is empty in a normal test run
- [ ] 2.12 Add `@Test("scenario: placed mountain tile picks its variant from its coord")` asserting the texture returned by `terrainTextureOrPlaceholder(for: .mountain, coord:)` matches `variantAssetName` for that coord
- [ ] 2.13 Add `@Test("scenario: placed road tile picks its variant from its coord")` for `.road` operational state
- [ ] 2.14 Add `@Test("scenario: ghost preview matches placement variant")` constructing a ghost at coord `(x, y)` and asserting its texture equals the variant texture for that coord

## 3. Validation and archival

- [ ] 3.1 Run `swift test --package-path Packages/CityRender2D` and confirm every new `@Test` from group 2 passes
- [ ] 3.2 Run `scripts/check-scenario-coverage.swift` and confirm every new `#### Scenario:` in the spec delta maps to a test
- [ ] 3.3 Run `make lint && make format` and confirm no diagnostics on the touched files
- [ ] 3.4 Run `openspec validate add-sprite-art-variants --strict` and confirm the change validates
- [ ] 3.5 Run `/opsx:archive` (or `openspec archive add-sprite-art-variants`) to land the spec delta into `openspec/specs/sprite-asset-pipeline/spec.md`
