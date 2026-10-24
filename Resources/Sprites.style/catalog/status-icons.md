---
source = "svg"
---
## Function

The status icon that floats over a building while something is wrong: a missing input, a house
short of a need, output that has nowhere to go, no road, no route to storage, no trees, no room to
plant. One icon per building at most, and none while the building works. Spec: `rendering-2_5d` /
Buildings show a status icon while something is wrong.

## Visual identity

A 24-point disc inside the goods icons' dark warm outline (`#2B1E15`), on a 28-point cell.
Pictograms are white on a red disc (blocked) or an amber disc (waiting), with a slash when something
is missing. A good's issue shows the goods icon on a cream disc with a pip in the lower right: a red
"!" when the good is short, an amber pause when output is stuck or the building rests on stock.
Design canvas: https://claude.ai/artifact/JMuRyVB1tHAFthEbFxdE2F (option A, "Disc").

## Sprites

- `status-beer-short`
- `status-beer-stuck`
- `status-bread-short`
- `status-bread-stuck`
- `status-charcoal-short`
- `status-charcoal-stuck`
- `status-coffee-cherries-short`
- `status-coffee-cherries-stuck`
- `status-coffee-short`
- `status-coffee-stuck`
- `status-flour-short`
- `status-flour-stuck`
- `status-food-short`
- `status-food-stuck`
- `status-grain-short`
- `status-grain-stuck`
- `status-grapes-short`
- `status-grapes-stuck`
- `status-hops-short`
- `status-hops-stuck`
- `status-iron-short`
- `status-iron-stuck`
- `status-no-road`
- `status-no-room-to-plant`
- `status-no-route`
- `status-no-trees`
- `status-ore-short`
- `status-ore-stuck`
- `status-planks-short`
- `status-planks-stuck`
- `status-storage-full`
- `status-tea-leaves-short`
- `status-tea-leaves-stuck`
- `status-tea-short`
- `status-tea-stuck`
- `status-tools-short`
- `status-tools-stuck`
- `status-wine-short`
- `status-wine-stuck`
- `status-wood-short`
- `status-wood-stuck`

## Recipe

- Source: `scripts/art/status_icons.py`, built on the goods icons in `scripts/art/goods_icons.py`,
  rendered by `art.svg_sprites` at @1x and @2x into `Kit.atlas`
