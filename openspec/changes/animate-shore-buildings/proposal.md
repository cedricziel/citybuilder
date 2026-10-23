## Why

The port and shipyard are the only working buildings that stand still (#120). The renderer has no operational animation entry for either, and their sprites carry a facing (`building-port-s-…`), so even the shipyard's two committed hull frames were never played. Design: https://claude.ai/artifact/AmtR3v8YiHoXfwLSDLXkRM (Port C and Shipyard B approved).

## What Changes

- **Port:** the crane brings cargo ashore in 6 frames, 0.45 s each. It lifts a crate off the wharf, swings it onto the quay beside the warehouse, sets it down, and swings back out. The jib, rope and crate are an IsoKit moving part (`crane`); the post stays in the building.
- **Shipyard:** the hull grows in 5 frames:
  - keel and ribs, then two, four and six strakes, 2.5 s each;
  - the finished hull holds for 4 s;
  - the empty slipway shows for 1.25 s, as if the hull had been launched, before a new keel is laid.
- `SpriteAnimation.Entry` gains optional per-frame durations.
- An operational shore building loops the frames of its own facing, the way a culture variant loops its own.
- The shore sprite inventory grows to 40 port and 36 shipyard sprites. The `Shore-building sprites per facing` requirement of `replace-generative-sprites-with-isokit` is updated in place, since that change is still open.

Out of scope: pausing building animations or slowing them under Reduce Motion. No building animation does either today.

## Capabilities

### New Capabilities
- (none)

### Modified Capabilities
- `rendering-2_5d`: adds "Port and shipyard animate while operational".

## Impact

- **IsoKit:** `ShoreRecipes.swift` gains the crane moving part and the hull stages, and the port and shipyard briefs list the new frames.
- **Kit.atlas:** 64 new PNGs. 56 PNGs are re-rendered because their content changed: the port's idle frame, operational frame 0 and construction stages 1–2 now show the crane in its new rest pose, and the shipyard's idle frame and frames 0–1 show the new hull stages.
- **CityRender2D:** `SpriteAnimation`, `CultureSprites.operationalAction` and `SceneNodeFactories`. The sprite catalog takes the shore frame counts from `SpriteAnimation`, and `SpriteName.shoreOperationalFrames` goes.
