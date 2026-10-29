## 1. Catchment radius in game data

- [x] 1.1 Tests-first in GameDataGen: `catchmentRadius` is emitted, a radius of 0 is rejected, and it appears in the optional-field fixtures and the diff; confirm red
- [x] 1.2 Model, loader, item schema, validator, emitter, JSON schema and FORMAT.md; `catchmentRadius: 2` on the hut and the forester; `make gamedata`
- [x] 1.3 Catchment helpers take the building kind and read its radius; `World.lumberjackCatchmentRadius` goes; render and UI read `kind.catchmentRadius`

## 2. Area-of-effect query

- [x] 2.1 Tests-first: a hut's area and targets, a forester's open grass, mine sites near the cursor without materials, nil for other kinds and for a selected mine; confirm red
- [x] 2.2 `AreaOfEffect` and `World.areaOfEffect(of:at:owner:placing:)`

## 3. Scene overlay

- [x] 3.1 Tests-first: outline path from a tile set, three nodes at most, tree tint applied and restored, target fill only on treeless targets; confirm red
- [x] 3.2 `areaOfEffectProvider` on the scene and `IsoWorldView`; `areaLayer` at z 4; tree tint re-applied while shown

## 4. Session, capsule and wiring

- [x] 4.1 Tests-first: `GameSession.areaOfEffect()` for the ghost and for a selection; capsule text and tones; nothing for an invalid ghost; confirm red
- [x] 4.2 `GameSession.areaOfEffect()` with its per-tick cache, the renderer factory parameter, and the three app shells
- [x] 4.3 `AreaCountCapsule` in the root view, sized per idiom

## 5. Shots and verification

- [x] 5.1 `-uiTestPlace` and `-uiTestSelect`, with tests
- [x] 5.2 Before and after shots on the Mac, an iPhone simulator and an Apple TV simulator: hut, forester, mine, a selected hut, and night or winter
- [x] 5.3 `make lint`, `make format`, the package tests, then `/simplify`

## 6. Review follow-ups (#242)

- [x] 6.1 The generator requires `catchmentRadius` with `plantTicks` and on the lumberjack hut
- [x] 6.2 No area for an anchor off the map; the shot flags ignore off-map tiles
- [x] 6.3 The capsule clears the touch nudge arrows at any zoom
- [x] 6.4 A red ghost with a catchment shows no area
- [x] 6.5 Test: the cached area is asked again on a new tick
