---
source = "svg"
---
## Function

Walkable ground overlay that speeds carrier movement and connects
buildings. Each road tile joins its paved neighbours, so a run of road
reads as one track and the town center's starter ring reads as a plaza.

## Visual identity

Painted by `scripts/art/roads.py` and lit like the terrain. Worn earth with gravel, the crown trodden
lighter and the verges darker where grass and mud meet the road; round the town center the ring is
cobbled to match its square. A tile is transparent off the road, so the terrain shows at its sides.
Its connection mask (arms to paved edge neighbours, corners where the diagonal is paved too) picks
the shape: bands of one fixed width from the centre to each connected edge, and filled quadrants
that close 2 x 2 blocks, so every join is seamless.

## Sprites

- `building-road` — base: a straight road, the build rail's icon
- `building-road-constructing-0` — construction stage 0
- `building-road-constructing-1` — construction stage 1
- `building-road-constructing-2` — construction stage 2
- `building-road-c0` — worn earth, mask 0
- `building-road-c1` — worn earth, mask 1
- `building-road-c2` — worn earth, mask 2
- `building-road-c3` — worn earth, mask 3
- `building-road-c19` — worn earth, mask 19
- `building-road-c4` — worn earth, mask 4
- `building-road-c5` — worn earth, mask 5
- `building-road-c6` — worn earth, mask 6
- `building-road-c38` — worn earth, mask 38
- `building-road-c7` — worn earth, mask 7
- `building-road-c23` — worn earth, mask 23
- `building-road-c39` — worn earth, mask 39
- `building-road-c55` — worn earth, mask 55
- `building-road-c8` — worn earth, mask 8
- `building-road-c9` — worn earth, mask 9
- `building-road-c137` — worn earth, mask 137
- `building-road-c10` — worn earth, mask 10
- `building-road-c11` — worn earth, mask 11
- `building-road-c27` — worn earth, mask 27
- `building-road-c139` — worn earth, mask 139
- `building-road-c155` — worn earth, mask 155
- `building-road-c12` — worn earth, mask 12
- `building-road-c76` — worn earth, mask 76
- `building-road-c13` — worn earth, mask 13
- `building-road-c77` — worn earth, mask 77
- `building-road-c141` — worn earth, mask 141
- `building-road-c205` — worn earth, mask 205
- `building-road-c14` — worn earth, mask 14
- `building-road-c46` — worn earth, mask 46
- `building-road-c78` — worn earth, mask 78
- `building-road-c110` — worn earth, mask 110
- `building-road-c15` — worn earth, mask 15
- `building-road-c31` — worn earth, mask 31
- `building-road-c47` — worn earth, mask 47
- `building-road-c63` — worn earth, mask 63
- `building-road-c79` — worn earth, mask 79
- `building-road-c95` — worn earth, mask 95
- `building-road-c111` — worn earth, mask 111
- `building-road-c127` — worn earth, mask 127
- `building-road-c143` — worn earth, mask 143
- `building-road-c159` — worn earth, mask 159
- `building-road-c175` — worn earth, mask 175
- `building-road-c191` — worn earth, mask 191
- `building-road-c207` — worn earth, mask 207
- `building-road-c223` — worn earth, mask 223
- `building-road-c239` — worn earth, mask 239
- `building-road-c255` — worn earth, mask 255
- `building-road-plaza-c0` — cobbled plaza, mask 0
- `building-road-plaza-c1` — cobbled plaza, mask 1
- `building-road-plaza-c2` — cobbled plaza, mask 2
- `building-road-plaza-c3` — cobbled plaza, mask 3
- `building-road-plaza-c19` — cobbled plaza, mask 19
- `building-road-plaza-c4` — cobbled plaza, mask 4
- `building-road-plaza-c5` — cobbled plaza, mask 5
- `building-road-plaza-c6` — cobbled plaza, mask 6
- `building-road-plaza-c38` — cobbled plaza, mask 38
- `building-road-plaza-c7` — cobbled plaza, mask 7
- `building-road-plaza-c23` — cobbled plaza, mask 23
- `building-road-plaza-c39` — cobbled plaza, mask 39
- `building-road-plaza-c55` — cobbled plaza, mask 55
- `building-road-plaza-c8` — cobbled plaza, mask 8
- `building-road-plaza-c9` — cobbled plaza, mask 9
- `building-road-plaza-c137` — cobbled plaza, mask 137
- `building-road-plaza-c10` — cobbled plaza, mask 10
- `building-road-plaza-c11` — cobbled plaza, mask 11
- `building-road-plaza-c27` — cobbled plaza, mask 27
- `building-road-plaza-c139` — cobbled plaza, mask 139
- `building-road-plaza-c155` — cobbled plaza, mask 155
- `building-road-plaza-c12` — cobbled plaza, mask 12
- `building-road-plaza-c76` — cobbled plaza, mask 76
- `building-road-plaza-c13` — cobbled plaza, mask 13
- `building-road-plaza-c77` — cobbled plaza, mask 77
- `building-road-plaza-c141` — cobbled plaza, mask 141
- `building-road-plaza-c205` — cobbled plaza, mask 205
- `building-road-plaza-c14` — cobbled plaza, mask 14
- `building-road-plaza-c46` — cobbled plaza, mask 46
- `building-road-plaza-c78` — cobbled plaza, mask 78
- `building-road-plaza-c110` — cobbled plaza, mask 110
- `building-road-plaza-c15` — cobbled plaza, mask 15
- `building-road-plaza-c31` — cobbled plaza, mask 31
- `building-road-plaza-c47` — cobbled plaza, mask 47
- `building-road-plaza-c63` — cobbled plaza, mask 63
- `building-road-plaza-c79` — cobbled plaza, mask 79
- `building-road-plaza-c95` — cobbled plaza, mask 95
- `building-road-plaza-c111` — cobbled plaza, mask 111
- `building-road-plaza-c127` — cobbled plaza, mask 127
- `building-road-plaza-c143` — cobbled plaza, mask 143
- `building-road-plaza-c159` — cobbled plaza, mask 159
- `building-road-plaza-c175` — cobbled plaza, mask 175
- `building-road-plaza-c191` — cobbled plaza, mask 191
- `building-road-plaza-c207` — cobbled plaza, mask 207
- `building-road-plaza-c223` — cobbled plaza, mask 223
- `building-road-plaza-c239` — cobbled plaza, mask 239
- `building-road-plaza-c255` — cobbled plaza, mask 255

## Recipe

- SVG generator: `scripts/art/roads.py` (`sources`)
- Texture: `scripts/art/roads.py` (`surface`: earth, plaza), lit by `scripts/art/ground.py`
