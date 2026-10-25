## Why

The owner asked for deeper production chains, so the economy shows real producer → producer flow (#239, part of the pacing work in #186). Today the shared chains are shallow: grain → flour → bread and ore + charcoal → iron → tools, plus one two-step luxury per culture. Merchants need four shared goods and a luxury, and they all appear within a few hours of each other, so the milestones bunch together.

A wool → cloth chain adds a third shared two-step chain and a fifth shared need. It is also the first chain whose raw producer is a herd, which fits the animals already grazing at the farms (#127).

## What Changes

- Two goods in the core pack: `wool` (raw) and `cloth` (made). `cloth` is declared `neededBy: [merchants]`, so merchants need food, planks, bread, tools and cloth, then their culture's luxury.
- Two buildings in the core pack, with the art from `isokit/wool-chain-art` (canvas: https://claude.ai/artifact/6NwF1t7K2N9DuZdohhp75Z, sheep farm option A and weaver option C):
  - `sheep-farm`, a gather building: 1 wool per 40 ticks, no inputs.
  - `weaver`, a craft building: 2 wool → 1 cloth per 50 ticks.
- One tech, `weaving` (medieval), unlocks both buildings.
- Merchants eat cloth at the rate tools and the luxuries use: 1 per 8 residents (rounded up) each consumption interval. No code is needed for the rate.
- The workshop sound loops reuse `fields` for the sheep farm and `mill` for the weaver. The PlayerBot (the scripted player the balance sweeps use) builds the chain on demand: it researches Weaving and builds sheep farms and a weaver once houses are close to becoming merchants, instead of a fixed number per set of houses.
- Cloth is required to advance to merchants, but a merchant house is held to it only once Weaving is researched, and a rival's house never is (rivals cannot make or buy cloth). Saves from before the chain and the Guild Town scenario therefore keep their merchants. The determinism baseline moves because the good list, the merchants' needs and the tech list change.

## Capabilities

### New Capabilities
<!-- None. -->

### Modified Capabilities
- `goods-and-production`: adds the wool and cloth chain.
- `population-and-needs`: merchants also need and consume cloth.
- `research`: adds the Weaving tech to the tech tree.
- `platform-shells`: the inspector's "Next:" line for citizens names cloth among the merchants' needs.

## Impact

- **Game data:** `Packages/CityCore/GameData/packs/core.yaml` gains two goods, two buildings and one tech. `make gamedata` regenerates `Good`, `BuildingKind`, `Tech`, `HouseTier` and the production catalog. No CityCore Swift changes besides the generated files.
- **Art and UI:** the IsoKit recipes, the goods icons and the style catalog entries already exist on `isokit/wool-chain-art`. This change wires them: the sprite atlas lists, the build drawer entries, the floating status icons (`StatusIcons.textureName(for:)`) and `design/web`.
- **Balance sweeps:** the PlayerBot kit and the pacing, solvency and rival sweeps are re-measured. The result is in design "Evidence".
- **Depends on:** `tier-needs-data` (merged; it provides `neededBy`). Per-good storage (`feat/per-good-storage-main`) changes the pack format in parallel (`storagePerGood` on stores, no `restAt`); the new goods carry neither field, so this change merges either way.
- **Saves and determinism:** the fixture is regenerated once, in its own commit.
