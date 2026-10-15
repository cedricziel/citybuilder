## Context

`replace-generative-sprites-with-isokit` moved every building, terrain tile and ship to IsoKit, but walkers are still the 8×12 pixel figure from the generative era. Its plan (D9) was a 10×16 kit figure with 4 gait frames. The owner then asked for real people and animals. A Claude Design canvas compared three scales, carriers on foot against ox and donkey carts, and ambient animals. The canvas approved option B, carriers on foot and the animals.

## Goals / Non-Goals

**Goals:**
- People and animals that read as such at zoom 1, lit like the buildings.
- One lookup for every walker look, so carriers, strollers and the plaza share frames.
- A small atlas budget that stays independent of how many walkers are on screen.

**Non-Goals:**
- Carts and draught animals. A carrier moves one unit; carts wait for bulk transport.
- 8 facings.
- Placing animals in the world: the life agent owns where animals stand and walk.

## Decisions

### D1. Storybook scale

The figure is a 1.7 m adult built from primitives: capsule limbs, a tapered tunic, a sphere head and a hat. The recipe scales it by 1.15, with a 1.25× head and 1.2× limbs. It stands about 21 pt tall, level with a 2 m door. At true scale (17 pt) the head and load shrink to a few pixels. The 1.4× "chunky" option read as toys next to the houses.

### D2. A narrow cell

A walker cell is 24×30 pt, much narrower than a 1×1 footprint (64 pt). `SpriteCell` gains an optional `widthPx`, centred on the same anchor, so the camera, light rig and cell-fit check stay unchanged. The feet sit 2 pt above the bottom edge (0.25 m up-screen of the footprint's bottom vertex), so the shadow under them stays in the cell. The renderer anchors walkers at `(0.5, 2/30)`.

### D3. Four facings, eight frames

Carriers step along the road grid, so every move is one of the four screen diagonals. With 8 facings, half the frames would never show and the atlas would double. Free-roaming figures snap to the nearest diagonal. The gait has 8 frames at 0.1 s per frame. The thigh swings ±0.42 rad, the knee bends on the forward swing, the arms counter-swing and the body bobs 2.5 cm. Loads hold the right arm up on the shoulder.

### D4. No mirroring

The sun comes from the screen's upper left. If a sprite is flipped with `xScale = -1`, the light moves to the other side. Every facing therefore has its own render, and nodes never mirror.

### D5. Carrier looks by good family

| Family | Goods |
|---|---|
| sack | grain, flour, food, hops, grapes, tea leaves, tea, coffee cherries, coffee |
| crate | bread, ore, charcoal, iron, tools |
| barrel | beer, wine |
| logs | wood, planks |

`SpriteAtlas.WalkerVariant.carrying(_:)` maps a good to its family, and the default branch maps any new good to the sack. The life agent's carrier node calls it.

### D6. Names and atlas

- People: `walker-<facing>-<frame>` (the worker) and `walker-<variant>-<facing>-<frame>`. The variants are `woman`, `carrier-sack`, `carrier-crate`, `carrier-barrel` and `carrier-logs`.
- Animals: `animal-<kind>-<action>-<facing>-<frame>` for `sheep` and `cow` with `walk` (8 frames) and `graze` (4 frames). Hens are `animal-hen-<facing>-<frame>`, 4 peck frames.

Every stem is kit-rendered, so routing sends all of them to `Kit` (linear filtering, @2x twins). `Units.atlas` keeps no walker art.

### D7. Budget

Measured at @2x as RGBA, trimmed to the opaque bounds the atlas compiler keeps:

| Set | Size |
|---|---|
| People (6 variants × 4 facings × 8 frames) | 1.3 MB |
| Sheep, cows and hens | 0.7 MB |

`Kit.atlas` holds about 68 MB. @1x costs a quarter as much. Textures are shared, so the number of walkers on screen adds nodes, not texture memory. Walkers draw from the same atlas as buildings, so their draws batch with them.

## Risks / Trade-offs

- **Shadows.** Baked shadows fall the same way on every walker, even at night. That matches the buildings.
- **Facing changes snap between frames.** Walkers have no turn frames.
- **The legacy walker brief and its tests change shape:** the gate's walker size and frame counts follow D2 and D3.
