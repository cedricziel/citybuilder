---
name: gamedata-culture
description: Create a complete new culture as one content pack (culture, luxury chain goods, garden, producer, signature building, tier names, resident names) and register it in the manifest. Use when the user wants a new playable culture.
---

# Add a culture

Copy the structure of an existing culture pack (`packs/cultures/northern-european.yaml`) exactly; change content, not shape.

## Checklist

1. **Culture item**: `name`, one-sentence `blurb` in the house style ("Sandstone, flat roofs and domes."), `tiers` for all three tiers, `luxury` chain, `signature`, at least 24 `residentNames`.
2. **Goods**: one raw (`basePrice` 3–5) and one luxury (`basePrice` 16). Ids must not collide with existing goods.
3. **Garden and producer** through the pack's own `garden` and `producer` anchors, both `culture:` set and `unlockedBy: cultivation`. Garden outputs the raw; producer turns 2 raw into 1 luxury.
4. **Signature building**: 3×3, cost 160–220, `effect: code`. Its bonus is Swift work: name the file (`CultureSignatures.swift` and the inspector lines) and either write it in the same change or list it as open work. Placement rules must be satisfiable on every generated island; avoid terrain counts above the mine's.
5. **Manifest**: append the pack after the last culture and before `ages`. Never reorder existing packs.
6. **Art**: list every catalog entry `SpritesStyleCatalogTests` will expect: the garden, producer and signature buildings, the per-culture house and library variants, and the per-age house looks.
7. **Sensitivity**: tier and resident names must belong to one coherent real-world tradition and be respectful. Say which tradition you drew from.

## Verify

```bash
make gamedata
xcrun swift run --package-path Packages/GameDataGen gamedata-gen diff HEAD
```

The semantic diff must contain only the new culture's items and the derived `cultivation` unlocks. Then `make gamedata-check` and the CityCore tests. Adding a culture changes rival setup, so determinism baselines need regenerating: say so.
