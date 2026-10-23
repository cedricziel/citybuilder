## 1. People in IsoKit

- [x] 1.1 Tests first: walker recipe names (6 variants × 4 facings × 8 frames), narrow `SpriteCell` width, cell fit and recipe rules for every walker recipe, and the unit bottom and shadow-reach checks in `CellFit`
- [x] 1.2 `SpriteCell(widthPx:)`; `Figures.swift` (figure, loads, cloth palette); `WalkerRecipes.swift` (storybook scale, six variants)

## 2. People in the game

- [x] 2.1 Tests first: walker lookup by look, 8-frame entry, routing to `Kit`, filtering stems equal the catalog, reverse coverage of every look, load, facing and frame, the content gate's walker size and frames
- [x] 2.2 `walker.md` → `source = "isokit"` with the full sheet; `make sprites`; delete `Units.atlas/walker-*` and retire the atlas
- [x] 2.3 `SpriteAnimation`/`SpriteAtlas` looks and the 8-frame gait, `walkerAnchor`; carrier, plaza and stroller nodes use the anchor and the real facing (no `xScale` mirroring)
- [ ] 2.4 In-game before/after (Mac, window-only capture); tell the life agent the lookup and names

## 3. Animals

- [x] 3.1 Tests first: animal recipe names and frame counts, lookup, routing, coverage
- [x] 3.2 `Animals.swift` and animal recipes; `animal.md` brief; `make sprites`
- [x] 3.3 `SpriteAtlas.animalAnimation(_:action:facing:)`; hand the names to the life agent

## 4. Follow-ups from the #155 review

- [x] 4.1 Retire `Units` in the `sprite-asset-pipeline` deltas (layout and routing), and route `walker-`, `carrier-`, `animal-` and `ship-` to Kit in `scripts/generate_sprites_ai/paths.py`
- [x] 4.2 Carriers and strollers stand on frame 0 while the game is paused; `playWalkCycle` keeps a running cycle and shares the cached loop only for a key's own frames
- [x] 4.3 Tests for the stroller and plaza anchors and for `playWalkCycle`

## 5. Close out

- [x] 5.1 Mark `replace-generative-sprites-with-isokit` task 4.7 done by this change; `make lint`, `make format`, `make sprites-verify`
