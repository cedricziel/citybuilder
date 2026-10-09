---
name: gamedata-tune
description: Change existing game-content values (costs, upkeep, recipes, cycle times, prices, tech costs, era gates) in the YAML content packs with a pin-pointed, verified edit. Use for any rebalance or tweak of an item that already exists. Not for adding items (gamedata-add) or cultures (gamedata-culture).
---

# Tune existing game content

One request, one minimal edit, proven by the semantic diff.

## 1. Locate

- Find the item by `kind` and `id`: `grep -rn "id: <id>" Packages/CityCore/GameData/packs/`.
- Read the whole item, plus any anchor it merges with `<<:` from the pack's `defaults`.
- Write down the change before editing: `<Kind> <id>: <field> <old> → <new>`. If the request is vague ("make bakeries cheaper"), propose concrete numbers and stop for confirmation.

## 2. Edit

- Change only the named fields. Never reformat, reorder or re-comment other lines.
- If the value comes from a merged anchor, override it **on the item**. Edit the anchor only when the request names every item that uses it; list those items first.
- Never edit `Sources/CityCore/Generated/` or any Swift file. If the value is not in a pack, stop and say where it lives.
- Never reorder items or packs: case order feeds the simulation.

## 3. Verify

```bash
make gamedata
xcrun swift run --package-path Packages/GameDataGen gamedata-gen diff HEAD
```

- The semantic diff must list exactly the changes written down in step 1. Anything else means the edit leaked, for example through a shared anchor: revert and redo.
- Run `make gamedata-check` and `xcrun swift test --package-path Packages/CityCore`.

## 4. Report

- Paste the semantic diff.
- Any value change alters simulation outcomes, so the determinism baselines need regenerating in the same change. Say so; do not regenerate them unless asked.
