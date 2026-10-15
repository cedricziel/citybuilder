## 1. People in IsoKit

- [ ] 1.1 Tests first: walker recipe names (6 variants × 4 facings × 8 frames), narrow `SpriteCell` width, cell fit and recipe rules for every walker recipe
- [ ] 1.2 `SpriteCell(widthPx:)`; `Figures.swift` (figure, loads, cloth palette); `WalkerRecipes.swift` (storybook scale, six variants)

## 2. People in the game

- [ ] 2.1 Tests first: walker lookup by variant, 8-frame entry, good → carrier family, routing to `Kit`, filtering stems equal the catalog, reverse coverage of every variant, facing and frame, the content gate's walker size and frames
- [ ] 2.2 `walker.md` → `source = "isokit"` with the full sheet; `make sprites`; delete `Units.atlas/walker-*`
- [ ] 2.3 `SpriteAnimation`/`SpriteAtlas` variants, `WalkerVariant.carrying`, `walkerAnchor`; carrier and stroller nodes use the anchor and the real facing (no `xScale` mirroring)
- [ ] 2.4 In-game before/after (Mac, window-only capture); tell the life agent the lookup and names

## 3. Animals

- [ ] 3.1 Tests first: animal recipe names and frame counts, lookup, routing, coverage
- [ ] 3.2 `Animals.swift` and animal recipes; `animal.md` brief; `make sprites`
- [ ] 3.3 `SpriteAtlas.animalAnimation(_:action:facing:)`; hand the names to the life agent

## 4. Close out

- [ ] 4.1 Mark `replace-generative-sprites-with-isokit` task 4.7 done by this change; `make lint`, `make format`, `make sprites-verify`
