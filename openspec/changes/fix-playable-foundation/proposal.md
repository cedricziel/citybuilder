## Why

A runtime playtest of `main` at `e57823e` (iPhone 17 Pro simulator, Single Island, seed 0) showed that the game is not playable. Four problems stack on top of each other:

- **Broken terrain art.** `terrain-water.png`, `terrain-water-1.png`, `terrain-mountain-v1.png`, and `terrain-mountain-v2.png` are house images, and `terrain-water-2.png` is fully transparent. The result is a strobing sea of houses and mountains covered in houses.
- **Gaps between tiles.** Every terrain tile covers only 30–60% of its 64×32 diamond, so a dark mesh shows through the whole map.
- **Placeholder HUD icons.** Xcode compiles `Icons.atlas` into `Icons.atlasc`, so `Bundle.main.url(forResource:withExtension:)` returns nil. Every good falls back to the same cube symbol.
- **No food producer.** Houses need food, but no building produces it, so population can never grow.

The existing CI gate (`make sprites-verify`) only checks that committed PNGs reproduce byte-for-byte. Nothing checks what a sprite actually shows.

This change has to land before `add-historical-ages`. That change multiplies the art count roughly fourfold and depends on a population loop that works.

## What Changes

- **Sprite content gate.** A new pipeline check runs in `make sprites-verify` and CI. It fails when:
  - a terrain sprite covers less than 90% of the iso diamond;
  - any frame is empty;
  - an animation frame differs too much from its sprite's base frame (palette-histogram distance above a threshold).

  These three rules catch every defect found in the playtest.
- **Diamond-fit normalisation.** Terrain sprites get a new post-processing step: scale the opaque region to the full 64×32 diamond, then clip with the diamond mask. Tiles then fill their diamond with no gaps.
- **Regenerate the defective terrain sprites:** water (all frames, using `two-pass: true`), `mountain-v1`, `mountain-v2`, and both beach frames. Regenerating needs `OPENAI_API_KEY`; the offline regen check covers the result.
- **HUD good icons** load from the compiled `Icons` texture atlas. Players can tell wood, planks, and food apart.
- **Food chain.** A new `farm` building (2×2, $60, materials: 2 wood) produces `food`. **BREAKING** (starter-balance requirement): the town center's starter inventory goes from 4 wood + 2 planks to **6 wood + 4 planks + 2 food**. The first session can then place a lumberjack, a farm, and a house without stalling.
- **Placement rejection feedback.** A rejected placement shows a transient HUD message that names the reason, such as "Needs 2 more planks" or "Tile occupied". Today a rejection does nothing visible.
- **Compact HUD layout.** On iPhone, HUD labels and palette entries stay on a single line, and money uses grouped digits. No more `$100` / `0` split across two lines, or "Ho / us / e".
- Tooling: the Makefile's iOS destination resolves to an installed simulator instead of the hard-coded `iPhone 16`.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `sprite-asset-pipeline`: adds the sprite content gate (diamond coverage, non-empty frames, frame coherence) and diamond-fit normalisation for terrain.
- `goods-and-production`: adds the farm → food recipe.
- `buildings-and-construction`: adds the `farm` building kind and the starting food stock.
- `platform-shells`: adds placement rejection feedback, atlas-backed good icons, and single-line compact HUD labels.

## Impact

- **CityCore:** new `BuildingKind.farm` case, a production recipe, a building spec, and starter food in `seedTownCenters`. Stays framework-free; no new imports.
- **CityRender2D:** the farm sprite name and animation entry.
- **CityUI:** `GoodIconLoader` resolves through the texture atlas, plus a rejection message in `HUDViewModel` and single-line compact layout.
- **CityPersistence:** no save-format change. Old saves don't contain farms, and the new enum case only adds a decode target. The save version stays 3.
- **Sprite pipeline (Python):** a new `content_gate.py` and a diamond-fit step for terrain. No new third-party packages; it uses the existing Pillow pin in `scripts/requirements.txt`.
- **Art:** new or regenerated PNGs for terrain water, mountain, and beach, plus the farm and its construction and operational frames. Regenerating needs `OPENAI_API_KEY` (about $0.04 per sprite). The offline CI check stays hermetic.
- **Build tools:** no new Homebrew dependency.
