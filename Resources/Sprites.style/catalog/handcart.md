---
source = "isokit"
---
## Function

A carrier on a long or bulk haul: one person pushing a two-wheeled handcart with up to 4 units (`SpriteAnimation.AnimationKey.handcart`). Four screen-diagonal facings, because every road step is one of them, and the walkers' 8-frame cycle at 0.1 s; frame 0 is the standing pose. Change: `visible-distribution`, milestone 3.

## Visual identity

Rendered by IsoKit in the shared light rig, with the cast shadow baked in. The pusher is a storybook-scale walker in a woad tunic, walnut hose and a straw hat, both hands forward on the handles. The cart is an open deal box on two spoked wheels that turn with the gait, loaded with two burlap sacks and a crate, whatever good it carries. Picked in the visible-distribution canvas (option B, https://claude.ai/artifact/2pupecCf6JAYUSkfi5LsWp). The cell is 64 x 48 pt so the cart fits ahead of the pusher in every facing; the pusher stands 14 pt above the cell's bottom edge, centred, and the renderer anchors there (`SpriteAtlas.handcartAnchor`, (32/64, 14/48)). Never mirrored: the light is baked in.

## Sprites

- `handcart-ne-0`
- `handcart-ne-1`
- `handcart-ne-2`
- `handcart-ne-3`
- `handcart-ne-4`
- `handcart-ne-5`
- `handcart-ne-6`
- `handcart-ne-7`
- `handcart-nw-0`
- `handcart-nw-1`
- `handcart-nw-2`
- `handcart-nw-3`
- `handcart-nw-4`
- `handcart-nw-5`
- `handcart-nw-6`
- `handcart-nw-7`
- `handcart-se-0`
- `handcart-se-1`
- `handcart-se-2`
- `handcart-se-3`
- `handcart-se-4`
- `handcart-se-5`
- `handcart-se-6`
- `handcart-se-7`
- `handcart-sw-0`
- `handcart-sw-1`
- `handcart-sw-2`
- `handcart-sw-3`
- `handcart-sw-4`
- `handcart-sw-5`
- `handcart-sw-6`
- `handcart-sw-7`

## Recipe

- Recipe: `handcart-<facing>` (IsoKit), one per facing
- Cell: 64×48 pt, pusher's feet at (32, 14) pt
- Facings: ne, nw, se, sw
- Frames per facing: 8
- Moving part: gait (the pusher's stride and the turning wheels)
