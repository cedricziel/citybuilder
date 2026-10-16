---
source = "isokit"
---
## Function

Every person walking the town: residents strolling and gathering on the plaza (`walker`, `walker-woman`, `SpriteAtlas.walkerAnimation(facing:look:)`) and carriers, who show the good they carry by family (`carrier-<load>`, `SpriteAtlas.carrierAnimation(load:facing:)`). Four screen-diagonal facings, because every road step is one of them, and an 8-frame walk cycle at 0.1 s; frame 0 is the standing pose. Change: `realistic-walkers`.

## Visual identity

Rendered by IsoKit in the shared light rig, with the cast shadow baked in. A walking figure built from primitives at storybook scale: 1.15x a 1.7 m adult with a 1.25x head and 1.2x limbs, about 21 pt tall, so the head reaches the 2 m door lintel. Period clothing in muted natural dyes (madder, woad, weld, walnut, undyed linen), picked greyer than the target because the warm sun saturates them. Hair over the back of the head tells walking away from walking toward the camera. Feet sit 2 pt above the cell's bottom edge; the renderer anchors at `SpriteAtlas.walkerAnchor`. Never mirrored: the light is baked in.

Looks:

- `walker`: the worker: madder tunic, fustian hose, felt cap
- `walker-woman`: a woman in a woad dress with a linen apron and coif, a bread basket on her head
- `carrier-sack`: a carrier with a sack on the shoulder, straw hat
- `carrier-crate`: a carrier with a crate on the shoulder
- `carrier-barrel`: a carrier with a barrel on the shoulder, hood
- `carrier-logs`: a carrier with three logs on the shoulder, straw hat

## Sheet

Grid: 8 cols × 24 rows. All 192 cells used.

- (0, 0): `walker-ne-0`
- (0, 1): `walker-ne-1`
- (0, 2): `walker-ne-2`
- (0, 3): `walker-ne-3`
- (0, 4): `walker-ne-4`
- (0, 5): `walker-ne-5`
- (0, 6): `walker-ne-6`
- (0, 7): `walker-ne-7`
- (1, 0): `walker-nw-0`
- (1, 1): `walker-nw-1`
- (1, 2): `walker-nw-2`
- (1, 3): `walker-nw-3`
- (1, 4): `walker-nw-4`
- (1, 5): `walker-nw-5`
- (1, 6): `walker-nw-6`
- (1, 7): `walker-nw-7`
- (2, 0): `walker-se-0`
- (2, 1): `walker-se-1`
- (2, 2): `walker-se-2`
- (2, 3): `walker-se-3`
- (2, 4): `walker-se-4`
- (2, 5): `walker-se-5`
- (2, 6): `walker-se-6`
- (2, 7): `walker-se-7`
- (3, 0): `walker-sw-0`
- (3, 1): `walker-sw-1`
- (3, 2): `walker-sw-2`
- (3, 3): `walker-sw-3`
- (3, 4): `walker-sw-4`
- (3, 5): `walker-sw-5`
- (3, 6): `walker-sw-6`
- (3, 7): `walker-sw-7`
- (4, 0): `walker-woman-ne-0`
- (4, 1): `walker-woman-ne-1`
- (4, 2): `walker-woman-ne-2`
- (4, 3): `walker-woman-ne-3`
- (4, 4): `walker-woman-ne-4`
- (4, 5): `walker-woman-ne-5`
- (4, 6): `walker-woman-ne-6`
- (4, 7): `walker-woman-ne-7`
- (5, 0): `walker-woman-nw-0`
- (5, 1): `walker-woman-nw-1`
- (5, 2): `walker-woman-nw-2`
- (5, 3): `walker-woman-nw-3`
- (5, 4): `walker-woman-nw-4`
- (5, 5): `walker-woman-nw-5`
- (5, 6): `walker-woman-nw-6`
- (5, 7): `walker-woman-nw-7`
- (6, 0): `walker-woman-se-0`
- (6, 1): `walker-woman-se-1`
- (6, 2): `walker-woman-se-2`
- (6, 3): `walker-woman-se-3`
- (6, 4): `walker-woman-se-4`
- (6, 5): `walker-woman-se-5`
- (6, 6): `walker-woman-se-6`
- (6, 7): `walker-woman-se-7`
- (7, 0): `walker-woman-sw-0`
- (7, 1): `walker-woman-sw-1`
- (7, 2): `walker-woman-sw-2`
- (7, 3): `walker-woman-sw-3`
- (7, 4): `walker-woman-sw-4`
- (7, 5): `walker-woman-sw-5`
- (7, 6): `walker-woman-sw-6`
- (7, 7): `walker-woman-sw-7`
- (8, 0): `carrier-sack-ne-0`
- (8, 1): `carrier-sack-ne-1`
- (8, 2): `carrier-sack-ne-2`
- (8, 3): `carrier-sack-ne-3`
- (8, 4): `carrier-sack-ne-4`
- (8, 5): `carrier-sack-ne-5`
- (8, 6): `carrier-sack-ne-6`
- (8, 7): `carrier-sack-ne-7`
- (9, 0): `carrier-sack-nw-0`
- (9, 1): `carrier-sack-nw-1`
- (9, 2): `carrier-sack-nw-2`
- (9, 3): `carrier-sack-nw-3`
- (9, 4): `carrier-sack-nw-4`
- (9, 5): `carrier-sack-nw-5`
- (9, 6): `carrier-sack-nw-6`
- (9, 7): `carrier-sack-nw-7`
- (10, 0): `carrier-sack-se-0`
- (10, 1): `carrier-sack-se-1`
- (10, 2): `carrier-sack-se-2`
- (10, 3): `carrier-sack-se-3`
- (10, 4): `carrier-sack-se-4`
- (10, 5): `carrier-sack-se-5`
- (10, 6): `carrier-sack-se-6`
- (10, 7): `carrier-sack-se-7`
- (11, 0): `carrier-sack-sw-0`
- (11, 1): `carrier-sack-sw-1`
- (11, 2): `carrier-sack-sw-2`
- (11, 3): `carrier-sack-sw-3`
- (11, 4): `carrier-sack-sw-4`
- (11, 5): `carrier-sack-sw-5`
- (11, 6): `carrier-sack-sw-6`
- (11, 7): `carrier-sack-sw-7`
- (12, 0): `carrier-crate-ne-0`
- (12, 1): `carrier-crate-ne-1`
- (12, 2): `carrier-crate-ne-2`
- (12, 3): `carrier-crate-ne-3`
- (12, 4): `carrier-crate-ne-4`
- (12, 5): `carrier-crate-ne-5`
- (12, 6): `carrier-crate-ne-6`
- (12, 7): `carrier-crate-ne-7`
- (13, 0): `carrier-crate-nw-0`
- (13, 1): `carrier-crate-nw-1`
- (13, 2): `carrier-crate-nw-2`
- (13, 3): `carrier-crate-nw-3`
- (13, 4): `carrier-crate-nw-4`
- (13, 5): `carrier-crate-nw-5`
- (13, 6): `carrier-crate-nw-6`
- (13, 7): `carrier-crate-nw-7`
- (14, 0): `carrier-crate-se-0`
- (14, 1): `carrier-crate-se-1`
- (14, 2): `carrier-crate-se-2`
- (14, 3): `carrier-crate-se-3`
- (14, 4): `carrier-crate-se-4`
- (14, 5): `carrier-crate-se-5`
- (14, 6): `carrier-crate-se-6`
- (14, 7): `carrier-crate-se-7`
- (15, 0): `carrier-crate-sw-0`
- (15, 1): `carrier-crate-sw-1`
- (15, 2): `carrier-crate-sw-2`
- (15, 3): `carrier-crate-sw-3`
- (15, 4): `carrier-crate-sw-4`
- (15, 5): `carrier-crate-sw-5`
- (15, 6): `carrier-crate-sw-6`
- (15, 7): `carrier-crate-sw-7`
- (16, 0): `carrier-barrel-ne-0`
- (16, 1): `carrier-barrel-ne-1`
- (16, 2): `carrier-barrel-ne-2`
- (16, 3): `carrier-barrel-ne-3`
- (16, 4): `carrier-barrel-ne-4`
- (16, 5): `carrier-barrel-ne-5`
- (16, 6): `carrier-barrel-ne-6`
- (16, 7): `carrier-barrel-ne-7`
- (17, 0): `carrier-barrel-nw-0`
- (17, 1): `carrier-barrel-nw-1`
- (17, 2): `carrier-barrel-nw-2`
- (17, 3): `carrier-barrel-nw-3`
- (17, 4): `carrier-barrel-nw-4`
- (17, 5): `carrier-barrel-nw-5`
- (17, 6): `carrier-barrel-nw-6`
- (17, 7): `carrier-barrel-nw-7`
- (18, 0): `carrier-barrel-se-0`
- (18, 1): `carrier-barrel-se-1`
- (18, 2): `carrier-barrel-se-2`
- (18, 3): `carrier-barrel-se-3`
- (18, 4): `carrier-barrel-se-4`
- (18, 5): `carrier-barrel-se-5`
- (18, 6): `carrier-barrel-se-6`
- (18, 7): `carrier-barrel-se-7`
- (19, 0): `carrier-barrel-sw-0`
- (19, 1): `carrier-barrel-sw-1`
- (19, 2): `carrier-barrel-sw-2`
- (19, 3): `carrier-barrel-sw-3`
- (19, 4): `carrier-barrel-sw-4`
- (19, 5): `carrier-barrel-sw-5`
- (19, 6): `carrier-barrel-sw-6`
- (19, 7): `carrier-barrel-sw-7`
- (20, 0): `carrier-logs-ne-0`
- (20, 1): `carrier-logs-ne-1`
- (20, 2): `carrier-logs-ne-2`
- (20, 3): `carrier-logs-ne-3`
- (20, 4): `carrier-logs-ne-4`
- (20, 5): `carrier-logs-ne-5`
- (20, 6): `carrier-logs-ne-6`
- (20, 7): `carrier-logs-ne-7`
- (21, 0): `carrier-logs-nw-0`
- (21, 1): `carrier-logs-nw-1`
- (21, 2): `carrier-logs-nw-2`
- (21, 3): `carrier-logs-nw-3`
- (21, 4): `carrier-logs-nw-4`
- (21, 5): `carrier-logs-nw-5`
- (21, 6): `carrier-logs-nw-6`
- (21, 7): `carrier-logs-nw-7`
- (22, 0): `carrier-logs-se-0`
- (22, 1): `carrier-logs-se-1`
- (22, 2): `carrier-logs-se-2`
- (22, 3): `carrier-logs-se-3`
- (22, 4): `carrier-logs-se-4`
- (22, 5): `carrier-logs-se-5`
- (22, 6): `carrier-logs-se-6`
- (22, 7): `carrier-logs-se-7`
- (23, 0): `carrier-logs-sw-0`
- (23, 1): `carrier-logs-sw-1`
- (23, 2): `carrier-logs-sw-2`
- (23, 3): `carrier-logs-sw-3`
- (23, 4): `carrier-logs-sw-4`
- (23, 5): `carrier-logs-sw-5`
- (23, 6): `carrier-logs-sw-6`
- (23, 7): `carrier-logs-sw-7`

## Animation

One 8-frame walk cycle per look and facing: the thigh swings, the knee bends on the forward swing, the arms counter-swing (a hand steadies a shouldered load or the basket) and the body bobs.

## Recipe

- Recipe: `walker-<facing>`, `walker-woman-<facing>`, `carrier-<load>-<facing>` (IsoKit), one per look and facing
- Cell: 24×30 pt, feet 2 pt up
- Facings: ne, nw, se, sw
- Frames per facing: 8
- Moving part: gait
