---
source = "isokit"
---
## Function

Ambient animals the life layer places around the town: sheep and cows grazing near farms and hens by the houses (`SpriteAtlas.animalAnimation(_:facing:)`). Sheep and cows walk (8 frames) and graze (4 frames); hens peck (4 frames). Four screen-diagonal facings, like the people. Frame 0 doubles as standing still. Change: `realistic-walkers`.

## Visual identity

Rendered by IsoKit in the shared light rig with the cast shadow baked in, at true size: a sheep is 1.1 m long with grey-cream wool and a black face and legs; a cow is 2 m long, dun with a pale flank and short horns; a hen is 30 cm, russet with a red comb, a fleck of colour by a house. Colours sit greyer than the target because the warm sun saturates them. Feet stand off the cell's bottom edge and left of its centre, so the stride and the whole shadow, which falls right, stay inside; the renderer anchors at `AnimalAction.anchor`, the points the Recipe section lists. Never mirrored.

## Sheet

Grid: 8 cols × 20 rows. Rows with 4 frames end in 4 spare cells.

- (0, 0): `animal-sheep-walk-ne-0`
- (0, 1): `animal-sheep-walk-ne-1`
- (0, 2): `animal-sheep-walk-ne-2`
- (0, 3): `animal-sheep-walk-ne-3`
- (0, 4): `animal-sheep-walk-ne-4`
- (0, 5): `animal-sheep-walk-ne-5`
- (0, 6): `animal-sheep-walk-ne-6`
- (0, 7): `animal-sheep-walk-ne-7`
- (1, 0): `animal-sheep-walk-nw-0`
- (1, 1): `animal-sheep-walk-nw-1`
- (1, 2): `animal-sheep-walk-nw-2`
- (1, 3): `animal-sheep-walk-nw-3`
- (1, 4): `animal-sheep-walk-nw-4`
- (1, 5): `animal-sheep-walk-nw-5`
- (1, 6): `animal-sheep-walk-nw-6`
- (1, 7): `animal-sheep-walk-nw-7`
- (2, 0): `animal-sheep-walk-se-0`
- (2, 1): `animal-sheep-walk-se-1`
- (2, 2): `animal-sheep-walk-se-2`
- (2, 3): `animal-sheep-walk-se-3`
- (2, 4): `animal-sheep-walk-se-4`
- (2, 5): `animal-sheep-walk-se-5`
- (2, 6): `animal-sheep-walk-se-6`
- (2, 7): `animal-sheep-walk-se-7`
- (3, 0): `animal-sheep-walk-sw-0`
- (3, 1): `animal-sheep-walk-sw-1`
- (3, 2): `animal-sheep-walk-sw-2`
- (3, 3): `animal-sheep-walk-sw-3`
- (3, 4): `animal-sheep-walk-sw-4`
- (3, 5): `animal-sheep-walk-sw-5`
- (3, 6): `animal-sheep-walk-sw-6`
- (3, 7): `animal-sheep-walk-sw-7`
- (4, 0): `animal-sheep-graze-ne-0`
- (4, 1): `animal-sheep-graze-ne-1`
- (4, 2): `animal-sheep-graze-ne-2`
- (4, 3): `animal-sheep-graze-ne-3`
- (4, 4): spare
- (4, 5): spare
- (4, 6): spare
- (4, 7): spare
- (5, 0): `animal-sheep-graze-nw-0`
- (5, 1): `animal-sheep-graze-nw-1`
- (5, 2): `animal-sheep-graze-nw-2`
- (5, 3): `animal-sheep-graze-nw-3`
- (5, 4): spare
- (5, 5): spare
- (5, 6): spare
- (5, 7): spare
- (6, 0): `animal-sheep-graze-se-0`
- (6, 1): `animal-sheep-graze-se-1`
- (6, 2): `animal-sheep-graze-se-2`
- (6, 3): `animal-sheep-graze-se-3`
- (6, 4): spare
- (6, 5): spare
- (6, 6): spare
- (6, 7): spare
- (7, 0): `animal-sheep-graze-sw-0`
- (7, 1): `animal-sheep-graze-sw-1`
- (7, 2): `animal-sheep-graze-sw-2`
- (7, 3): `animal-sheep-graze-sw-3`
- (7, 4): spare
- (7, 5): spare
- (7, 6): spare
- (7, 7): spare
- (8, 0): `animal-cow-walk-ne-0`
- (8, 1): `animal-cow-walk-ne-1`
- (8, 2): `animal-cow-walk-ne-2`
- (8, 3): `animal-cow-walk-ne-3`
- (8, 4): `animal-cow-walk-ne-4`
- (8, 5): `animal-cow-walk-ne-5`
- (8, 6): `animal-cow-walk-ne-6`
- (8, 7): `animal-cow-walk-ne-7`
- (9, 0): `animal-cow-walk-nw-0`
- (9, 1): `animal-cow-walk-nw-1`
- (9, 2): `animal-cow-walk-nw-2`
- (9, 3): `animal-cow-walk-nw-3`
- (9, 4): `animal-cow-walk-nw-4`
- (9, 5): `animal-cow-walk-nw-5`
- (9, 6): `animal-cow-walk-nw-6`
- (9, 7): `animal-cow-walk-nw-7`
- (10, 0): `animal-cow-walk-se-0`
- (10, 1): `animal-cow-walk-se-1`
- (10, 2): `animal-cow-walk-se-2`
- (10, 3): `animal-cow-walk-se-3`
- (10, 4): `animal-cow-walk-se-4`
- (10, 5): `animal-cow-walk-se-5`
- (10, 6): `animal-cow-walk-se-6`
- (10, 7): `animal-cow-walk-se-7`
- (11, 0): `animal-cow-walk-sw-0`
- (11, 1): `animal-cow-walk-sw-1`
- (11, 2): `animal-cow-walk-sw-2`
- (11, 3): `animal-cow-walk-sw-3`
- (11, 4): `animal-cow-walk-sw-4`
- (11, 5): `animal-cow-walk-sw-5`
- (11, 6): `animal-cow-walk-sw-6`
- (11, 7): `animal-cow-walk-sw-7`
- (12, 0): `animal-cow-graze-ne-0`
- (12, 1): `animal-cow-graze-ne-1`
- (12, 2): `animal-cow-graze-ne-2`
- (12, 3): `animal-cow-graze-ne-3`
- (12, 4): spare
- (12, 5): spare
- (12, 6): spare
- (12, 7): spare
- (13, 0): `animal-cow-graze-nw-0`
- (13, 1): `animal-cow-graze-nw-1`
- (13, 2): `animal-cow-graze-nw-2`
- (13, 3): `animal-cow-graze-nw-3`
- (13, 4): spare
- (13, 5): spare
- (13, 6): spare
- (13, 7): spare
- (14, 0): `animal-cow-graze-se-0`
- (14, 1): `animal-cow-graze-se-1`
- (14, 2): `animal-cow-graze-se-2`
- (14, 3): `animal-cow-graze-se-3`
- (14, 4): spare
- (14, 5): spare
- (14, 6): spare
- (14, 7): spare
- (15, 0): `animal-cow-graze-sw-0`
- (15, 1): `animal-cow-graze-sw-1`
- (15, 2): `animal-cow-graze-sw-2`
- (15, 3): `animal-cow-graze-sw-3`
- (15, 4): spare
- (15, 5): spare
- (15, 6): spare
- (15, 7): spare
- (16, 0): `animal-hen-ne-0`
- (16, 1): `animal-hen-ne-1`
- (16, 2): `animal-hen-ne-2`
- (16, 3): `animal-hen-ne-3`
- (16, 4): spare
- (16, 5): spare
- (16, 6): spare
- (16, 7): spare
- (17, 0): `animal-hen-nw-0`
- (17, 1): `animal-hen-nw-1`
- (17, 2): `animal-hen-nw-2`
- (17, 3): `animal-hen-nw-3`
- (17, 4): spare
- (17, 5): spare
- (17, 6): spare
- (17, 7): spare
- (18, 0): `animal-hen-se-0`
- (18, 1): `animal-hen-se-1`
- (18, 2): `animal-hen-se-2`
- (18, 3): `animal-hen-se-3`
- (18, 4): spare
- (18, 5): spare
- (18, 6): spare
- (18, 7): spare
- (19, 0): `animal-hen-sw-0`
- (19, 1): `animal-hen-sw-1`
- (19, 2): `animal-hen-sw-2`
- (19, 3): `animal-hen-sw-3`
- (19, 4): spare
- (19, 5): spare
- (19, 6): spare
- (19, 7): spare

## Animation

Walking, diagonal leg pairs swing together and the body bobs. Grazing, the head is down and the jaw works. Pecking, the hen's head dips to the ground and back.

## Recipe

- Recipe: `animal-<sheep|cow>-<walk|graze>-<facing>`, `animal-hen-<facing>` (IsoKit), one per action and facing
- Cell: sheep 34×26 pt, cow 52×44 pt, hen 18×14 pt
- Anchor sheep: feet at 14, 7 in 34×26
- Anchor cow: feet at 21, 11 in 52×44
- Anchor hen: feet at 8, 4 in 18×14
- Facings: ne, nw, se, sw
- Frames per facing: walk 8, graze 4, peck 4
- Moving part: gait
