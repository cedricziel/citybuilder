---
name: gamedata-add
description: Add a good, building or tech to the YAML content packs, wired into an existing production chain, with references, placement, effect and consumer checks done right. Use when one or a few items join existing content. For a whole culture use gamedata-culture; for changing existing values use gamedata-tune.
---

# Add game content

## 1. Plan before editing

Write a plan and confirm it with the user when anything is a judgement call:

- **Pack**: the feature the item belongs to. Culture-only content goes in that culture's pack, shared content in `core`, age content in `ages`. A new feature area gets a new pack, appended to the end of `GameData/index.yaml` (never inserted: order is case order).
- **References point outward**: the new building names its tech (`unlockedBy`), its culture, the goods it uses. Never edit an existing item to point at the new one.
- **Consumer**: every new good needs a consumer: a recipe input, a material, a luxury, or a house tier need. If the only consumer would be a tier need, stop: that needs the `tier-needs-data` change.
- **Behaviour**: a building either has a recipe that produces goods, or `effect: code`. Choose `effect: code` only when Swift behaviour exists or will be written in the same change; say which Swift file.
- **Art**: every new building and good needs sprite catalog entries (`Resources/Sprites.style/catalog/`). List them as follow-up work for the sprite pipeline.
- **Numbers**: start from the closest existing item and the balance bands in the format reference.

## 2. Edit

- Append items at the end of the chosen pack's relevant section. Reuse the pack's `defaults` anchors where they fit.
- Give buildings a `name` when the title-cased id would read badly.

## 3. Verify

```bash
make gamedata
xcrun swift run --package-path Packages/GameDataGen gamedata-gen diff HEAD
```

- The semantic diff must show only additions (plus the derived `Tech.unlocks` entry). Any changed existing value means a mistake.
- Run `make gamedata-check` and `xcrun swift test --package-path Packages/CityCore`. Expect `SpritesStyleCatalogTests` to fail until the art exists; report it, do not stub catalog files.

## 4. Report

The semantic diff, the sprite entries needed, any Swift behaviour still to write, and that determinism baselines need regenerating.
