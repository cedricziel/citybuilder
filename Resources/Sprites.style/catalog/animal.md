---
source = "isokit"
---
## Function

Ambient animals the life layer places around the town: sheep and cows grazing near farms and hens by the houses (`SpriteAtlas.animalAnimation(_:facing:)`). Sheep and cows walk (8 frames) and graze (4 frames); hens peck (4 frames). Four screen-diagonal facings, like the people. Frame 0 doubles as standing still. Change: `realistic-walkers`.

## Visual identity

Rendered by IsoKit in the shared light rig with the cast shadow baked in, at true size: a sheep is 1.1 m long with grey-cream wool and a black face and legs; a cow is 2 m long, dun with a pale flank and short horns; a hen is 30 cm, russet with a red comb, a fleck of colour by a house. Colours sit greyer than the target because the warm sun saturates them. Feet stand off the cell's bottom edge and left of its centre, so the stride and the whole shadow, which falls right, stay inside; the renderer anchors at `AnimalAction.anchor`, the points the Recipe section lists. Never mirrored.

## Sprites

- `animal-sheep-walk-ne-0`
- `animal-sheep-walk-ne-1`
- `animal-sheep-walk-ne-2`
- `animal-sheep-walk-ne-3`
- `animal-sheep-walk-ne-4`
- `animal-sheep-walk-ne-5`
- `animal-sheep-walk-ne-6`
- `animal-sheep-walk-ne-7`
- `animal-sheep-walk-nw-0`
- `animal-sheep-walk-nw-1`
- `animal-sheep-walk-nw-2`
- `animal-sheep-walk-nw-3`
- `animal-sheep-walk-nw-4`
- `animal-sheep-walk-nw-5`
- `animal-sheep-walk-nw-6`
- `animal-sheep-walk-nw-7`
- `animal-sheep-walk-se-0`
- `animal-sheep-walk-se-1`
- `animal-sheep-walk-se-2`
- `animal-sheep-walk-se-3`
- `animal-sheep-walk-se-4`
- `animal-sheep-walk-se-5`
- `animal-sheep-walk-se-6`
- `animal-sheep-walk-se-7`
- `animal-sheep-walk-sw-0`
- `animal-sheep-walk-sw-1`
- `animal-sheep-walk-sw-2`
- `animal-sheep-walk-sw-3`
- `animal-sheep-walk-sw-4`
- `animal-sheep-walk-sw-5`
- `animal-sheep-walk-sw-6`
- `animal-sheep-walk-sw-7`
- `animal-sheep-graze-ne-0`
- `animal-sheep-graze-ne-1`
- `animal-sheep-graze-ne-2`
- `animal-sheep-graze-ne-3`
- `animal-sheep-graze-nw-0`
- `animal-sheep-graze-nw-1`
- `animal-sheep-graze-nw-2`
- `animal-sheep-graze-nw-3`
- `animal-sheep-graze-se-0`
- `animal-sheep-graze-se-1`
- `animal-sheep-graze-se-2`
- `animal-sheep-graze-se-3`
- `animal-sheep-graze-sw-0`
- `animal-sheep-graze-sw-1`
- `animal-sheep-graze-sw-2`
- `animal-sheep-graze-sw-3`
- `animal-cow-walk-ne-0`
- `animal-cow-walk-ne-1`
- `animal-cow-walk-ne-2`
- `animal-cow-walk-ne-3`
- `animal-cow-walk-ne-4`
- `animal-cow-walk-ne-5`
- `animal-cow-walk-ne-6`
- `animal-cow-walk-ne-7`
- `animal-cow-walk-nw-0`
- `animal-cow-walk-nw-1`
- `animal-cow-walk-nw-2`
- `animal-cow-walk-nw-3`
- `animal-cow-walk-nw-4`
- `animal-cow-walk-nw-5`
- `animal-cow-walk-nw-6`
- `animal-cow-walk-nw-7`
- `animal-cow-walk-se-0`
- `animal-cow-walk-se-1`
- `animal-cow-walk-se-2`
- `animal-cow-walk-se-3`
- `animal-cow-walk-se-4`
- `animal-cow-walk-se-5`
- `animal-cow-walk-se-6`
- `animal-cow-walk-se-7`
- `animal-cow-walk-sw-0`
- `animal-cow-walk-sw-1`
- `animal-cow-walk-sw-2`
- `animal-cow-walk-sw-3`
- `animal-cow-walk-sw-4`
- `animal-cow-walk-sw-5`
- `animal-cow-walk-sw-6`
- `animal-cow-walk-sw-7`
- `animal-cow-graze-ne-0`
- `animal-cow-graze-ne-1`
- `animal-cow-graze-ne-2`
- `animal-cow-graze-ne-3`
- `animal-cow-graze-nw-0`
- `animal-cow-graze-nw-1`
- `animal-cow-graze-nw-2`
- `animal-cow-graze-nw-3`
- `animal-cow-graze-se-0`
- `animal-cow-graze-se-1`
- `animal-cow-graze-se-2`
- `animal-cow-graze-se-3`
- `animal-cow-graze-sw-0`
- `animal-cow-graze-sw-1`
- `animal-cow-graze-sw-2`
- `animal-cow-graze-sw-3`
- `animal-hen-ne-0`
- `animal-hen-ne-1`
- `animal-hen-ne-2`
- `animal-hen-ne-3`
- `animal-hen-nw-0`
- `animal-hen-nw-1`
- `animal-hen-nw-2`
- `animal-hen-nw-3`
- `animal-hen-se-0`
- `animal-hen-se-1`
- `animal-hen-se-2`
- `animal-hen-se-3`
- `animal-hen-sw-0`
- `animal-hen-sw-1`
- `animal-hen-sw-2`
- `animal-hen-sw-3`

## Recipe

- Recipe: `animal-<sheep|cow>-<walk|graze>-<facing>`, `animal-hen-<facing>` (IsoKit), one per action and facing
- Cell: sheep 34×26 pt, cow 52×44 pt, hen 18×14 pt
- Anchor sheep: feet at 14, 7 in 34×26
- Anchor cow: feet at 21, 11 in 52×44
- Anchor hen: feet at 8, 4 in 18×14
- Facings: ne, nw, se, sw
- Frames per facing: walk 8, graze 4, peck 4
- Moving part: gait
