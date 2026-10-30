---
source = "isokit"
---
## Function

A market porter carrying house goods from a hub (the town center or a marketplace) to a house and walking back (`SpriteAnimation.AnimationKey.porter`). `porter` shows the baskets filled on the way out, `porter-empty` shows them empty on the way back. Four screen-diagonal facings, because every road step is one of them, and the walkers' 8-frame cycle at 0.1 s; frame 0 is the standing pose. Change: `visible-distribution`, milestone 2.

## Visual identity

Rendered by IsoKit in the shared light rig, with the cast shadow baked in. A storybook-scale walker in a weld tunic, walnut hose and a felt cap, a bark pole across the shoulders square to the walk, both hands up steadying it, and a wicker basket hung from each end by two leather cords. Filled baskets show a mound of goods; empty ones show the wicker only. Picked in the visible-distribution canvas (option B, the shoulder yoke, https://claude.ai/artifact/2pupecCf6JAYUSkfi5LsWp). It shares the walkers' 32 x 32 pt cell and anchor (`SpriteAtlas.walkerAnchor`, (12/32, 5/32)), so its wide silhouette tells porters from sack carriers without a cell of its own. Never mirrored: the light is baked in.

## Sprites

- `porter-ne-0`
- `porter-ne-1`
- `porter-ne-2`
- `porter-ne-3`
- `porter-ne-4`
- `porter-ne-5`
- `porter-ne-6`
- `porter-ne-7`
- `porter-nw-0`
- `porter-nw-1`
- `porter-nw-2`
- `porter-nw-3`
- `porter-nw-4`
- `porter-nw-5`
- `porter-nw-6`
- `porter-nw-7`
- `porter-se-0`
- `porter-se-1`
- `porter-se-2`
- `porter-se-3`
- `porter-se-4`
- `porter-se-5`
- `porter-se-6`
- `porter-se-7`
- `porter-sw-0`
- `porter-sw-1`
- `porter-sw-2`
- `porter-sw-3`
- `porter-sw-4`
- `porter-sw-5`
- `porter-sw-6`
- `porter-sw-7`
- `porter-empty-ne-0`
- `porter-empty-ne-1`
- `porter-empty-ne-2`
- `porter-empty-ne-3`
- `porter-empty-ne-4`
- `porter-empty-ne-5`
- `porter-empty-ne-6`
- `porter-empty-ne-7`
- `porter-empty-nw-0`
- `porter-empty-nw-1`
- `porter-empty-nw-2`
- `porter-empty-nw-3`
- `porter-empty-nw-4`
- `porter-empty-nw-5`
- `porter-empty-nw-6`
- `porter-empty-nw-7`
- `porter-empty-se-0`
- `porter-empty-se-1`
- `porter-empty-se-2`
- `porter-empty-se-3`
- `porter-empty-se-4`
- `porter-empty-se-5`
- `porter-empty-se-6`
- `porter-empty-se-7`
- `porter-empty-sw-0`
- `porter-empty-sw-1`
- `porter-empty-sw-2`
- `porter-empty-sw-3`
- `porter-empty-sw-4`
- `porter-empty-sw-5`
- `porter-empty-sw-6`
- `porter-empty-sw-7`

## Recipe

- Recipe: `porter-<facing>` and `porter-empty-<facing>` (IsoKit), one per facing
- Cell: 32×32 pt, feet at (12, 5) pt
- Facings: ne, nw, se, sw
- Frames per facing: 8
- Moving part: gait
