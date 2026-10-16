## Why

The walkers are 8×12 pt pixel figures with two frames. Next to the lit, pre-rendered 3D houses they read as red dots, about a third of the door's height. The owner wants real people and animals: a warm, lived-in period town (#84, #127). The approved canvas is https://claude.ai/artifact/D5c7NgpR5bWTyWqj9DXeip.

## What Changes

- **People are modelled in IsoKit** under the buildings' light rig, with the cast shadow baked in. The approved scale is "storybook": a 1.7 m adult at 1.15×, with a 1.25× head and 1.2× limbs, about 21 pt tall, so the head reaches the 2 m door lintel. Clothing uses muted natural dyes.
- **Six people looks:** the worker (the default), a woman with a basket, and four carriers, one per good family (sack, crate, barrel, logs) under the `carrier-<load>` names of `add-carrier-glide`.
- **Eight-frame walk cycle** at 0.1 s per frame in the four screen diagonals `ne`, `se`, `sw`, `nw`. Frame 0 is the idle pose.
- **Animals** for ambient life: sheep and cows (8-frame walk, 4-frame graze) and hens (4-frame peck).
- **Sprites move to `Kit.atlas`** (linear filtering, @1x and @2x). Walkers are 24×30 pt with their feet 2 pt above the bottom edge, so the shadow fits. The legacy `walker-*` PNGs are deleted and the empty `Units` atlas is retired.
- **Renderer:**
  - `SpriteAtlas.walkerAnimation(facing:look:)` looks up the resident looks; `walkerAnimation(facing:)` stays the worker's, and `carrierAnimation(load:facing:)` (add-carrier-glide) finds the carrier art.
  - `SpriteAtlas.animalAnimation` looks up the animals.
  - Walker nodes anchor at the feet and never mirror a lit sprite with `xScale`.
- **No carts.** A carrier moves one unit of a good, tile by tile, and an ox cart is longer than a road tile. Carts wait for bulk transport.

## Capabilities

### New Capabilities
- (none)

### Modified Capabilities
- `sprite-asset-pipeline`: walker and animal names, sizes and frame counts; both route to `Kit`.
- `sprite-animation`: walker variants, the 8-frame gait and the animal lookups.
- `rendering-2_5d`: figures stand on their feet, face where they go without mirroring, and carriers show their load.

## Impact

- **Tools/IsoKit:** new `Figures.swift`, `WalkerRecipes.swift` and `Animals.swift` under `Recipes/`. `SpriteCell` takes an optional narrow width. No change to Builder, Materials or Rig.
- **Resources:**
  - `walker.md` flips to `source = "isokit"`, and a new `animal.md` brief is added.
  - About 2.0 MB of trimmed @2x RGBA lands in `Kit.atlas`, which holds about 68 MB today.
  - `Units.atlas` loses its walker PNGs.
- **CityRender2D:**
  - `SpriteAnimation` and `SpriteAtlas` (variants and animals)
  - `TextureFiltering` stems
  - the content gate's walker rules
  - the carrier and stroller nodes (anchor and facing)
- **Other agents:** the life agent places the animals and wires the carriers' good-family hook and the plaza variety through these lookups.
- **`replace-generative-sprites-with-isokit`:** its walker task (4.7), design D9 and the 10×16 walker requirement are superseded by this change.
