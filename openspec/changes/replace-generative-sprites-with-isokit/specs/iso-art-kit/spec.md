## ADDED Requirements

### Requirement: IsoKit renders every building and unit sprite

A Swift package at `Tools/IsoKit` SHALL provide an `isokit` executable that renders sprites offline from recipes written in code:

- **Buildings:** for every building kind in the sprite catalog, the idle sprite, the construction frames and the operational frames (or the orientations, for shore buildings).
- **Units:** the facing and frame set their grammar defines, with no construction or operational states. Walkers and animals have the facings and frames `realistic-walkers` defines; ships have 8 facings × their frame count.

The package MUST NOT be linked into any app target, and MUST NOT make network requests.

#### Scenario: Every catalogued building kind has a recipe

- **WHEN** the IsoKit recipe registry is compared with the building and unit entries of the sprite catalog
- **THEN** every catalog entry names a registered recipe and every recipe has a catalog entry

#### Scenario: Rendering needs no network

- **WHEN** `isokit render` runs with networking disabled
- **THEN** it writes every building and unit PNG and exits zero

### Requirement: Fixed isometric camera and cell geometry

IsoKit SHALL render through one orthographic camera with:

- euler angles (−30°, 45°, 0) and vertical projection
- a scale of 64 / (4·√2) points per metre, where one tile is 4 m

An n×n footprint renders into a cell at least 64·n points wide. A building's cell widens symmetrically, in 16-point steps, until its baked shadow fits, so no shadow ends in a hard edge at the sprite's side. The footprint's bottom vertex MUST sit at the cell's bottom-centre. Each recipe declares its cell height, and no part of the building may be clipped by the cell's top edge.

#### Scenario: A 2×2 house renders centred in its cell

- **WHEN** the peasant house recipe (2×2 footprint) is rendered at @1×
- **THEN** the PNG is as wide as its cell, at least 128 pixels, and its lowest opaque pixel is in the bottom row at the horizontal centre ±2 pixels

#### Scenario: A building's shadow fits its cell

- **WHEN** a building's baked shadow reaches past its footprint's width
- **THEN** its cell widens until the shadow fits, and the IsoKit test suite fails for any building whose shadow leaves its cell

#### Scenario: A recipe taller than its cell is rejected

- **WHEN** a recipe's tallest point projects above its declared cell height
- **THEN** the IsoKit test suite fails and names the recipe

### Requirement: One light rig and finish set

Every IsoKit render SHALL use the same light rig:

- one directional warm sun from screen upper-left, casting soft shadows
- one ambient sky fill
- the camera's screen-space ambient occlusion

Every surface SHALL use a finish from the shared finish set. Recipes MUST NOT add lights or define materials of their own.

#### Scenario: Recipes cannot add lights

- **WHEN** a recipe's node tree is inspected after building
- **THEN** it contains no node with an `SCNLight`

#### Scenario: Recipes use shared finishes

- **WHEN** every material in a built recipe is compared with the finish set
- **THEN** each material was produced by a finish from the set

### Requirement: Construction stages come from the recipe

A building recipe SHALL be able to build itself at each construction stage. IsoKit SHALL render stages 0, 1 and 2 as `building-<kind>-constructing-0…2`:

- stage 0: plinth and bare frame
- stage 1: walls and roof boards
- stage 2: near-finished, with scaffold

#### Scenario: A house renders three construction frames

- **WHEN** IsoKit renders the house family
- **THEN** `building-house-constructing-0.png`, `-1.png` and `-2.png` are written and each passes the content gate

### Requirement: Moving parts render as operational frames

A recipe MAY declare a moving part (sails, saw, wheel) with a frame count. For each frame, IsoKit SHALL:

1. render the part with the building drawn depth-only and no ground
2. composite that overlay onto the idle sprite
3. write it as `building-<kind>-operational-<n>`

#### Scenario: Sawmill sails turn across operational frames

- **WHEN** IsoKit renders the sawmill with a 4-frame sails part
- **THEN** `building-sawmill-operational-0…3.png` are written, they differ only where the sails are, and the building pixels match the idle sprite within the regen tolerance

### Requirement: Houses and workshops render night lights

For every house look and every workshop whose finished building shows a window pane, IsoKit SHALL also write three evenings of lights, `<sprite id>-lights-0` to `-2`, at the sprite's size and anchor. Each variant SHALL:

1. light a seeded subset of the panes, about 30%, at least one and at most three on a building with twelve panes or fewer, lower panes likelier than upper ones
2. draw the lit panes unlit in oil-lamp amber (blue glass bands dimmer)
3. draw everything else, the dark panes included, to depth only and before the lit panes, so it hides what is behind it and leaves no colour
4. add no light to the scene

A variant whose lit panes are all hidden is reseeded. A building whose panes are all hidden gets no lights files.

The day sprites (finished, construction and operational frames) SHALL show every pane as dark glass: no material of a recipe MAY emit light, so window light comes only from the lights variants.

#### Scenario: Night lights glow from a few of the panes

- **WHEN** IsoKit builds an evening's lights of a house with eight windows
- **THEN** two panes glow, every other part writes depth only and draws before them, and a shed without a pane has no lights

#### Scenario: Day sprites never glow

- **WHEN** a recipe gives a pane a material that emits light
- **THEN** the recipe rules reject it

#### Scenario: Every house look ships its lights

- **WHEN** the committed Kit atlas is checked
- **THEN** each of the 60 house looks has all three `-lights-<n>` at both scales, and every lights file sits beside its sprite

### Requirement: Terrain tiles come from SVG generators

A generator under `scripts/art/` SHALL write the SVG sources for:

- the terrain transition tiles
- the full-tile variants

The goods icons are committed pixel art until hand-authored SVG sources replace them.

It SHALL render them to PNG with `rsvg-convert`. Transition tiles use corner masks 1–14 for the pairs grass→beach and beach→water. Every boundary MUST cross a tile edge at the edge's midpoint. Texture patterns MUST repeat on a 32×16-point period.

#### Scenario: Both transition sets are complete

- **WHEN** the terrain generator runs
- **THEN** it writes `terrain-grass-beach-t1` … `-t14` and `terrain-beach-water-t1` … `-t14`

#### Scenario: Neighbouring transition tiles join without a seam

- **WHEN** any two transition tiles of the same pair whose shared corners agree are composited one column east (+col) or one row south (+row) of each other
- **THEN** no pixel along their shared edge is transparent, and colour changes across the edge only where the boundary curve crosses it

### Requirement: Road tiles come from the road generator

`scripts/art/roads.py` SHALL draw every road sprite: each connection mask on the worn-earth and the cobbled plaza surface, the base road and its construction stages. Arms are bands of one fixed width from the tile centre to an edge midpoint; a corner fills the quadrant between its arms up to the shared vertex. Surfaces are tile-periodic and lit like the terrain. A tile is transparent off the road.

#### Scenario: Road tiles join without a step
- **WHEN** random networks of road are laid out and each tile takes its connection mask
- **THEN** road cover matches on both sides of every edge two road tiles share

### Requirement: Offline render within a tolerance

`make sprites` SHALL build IsoKit with `xcrun swift` and run it and the SVG generators. It writes the atlas PNGs of every catalog entry whose `source` is `isokit` or `svg`. Entries not yet migrated keep their committed PNGs, which makes rollout one family at a time possible. Once every family has migrated, this covers every atlas PNG.

`make sprites-verify` SHALL re-render the same set of entries into a scratch directory and compare each fresh render with its committed (indexed) PNG, both premultiplied by alpha. It fails when a PNG's mean absolute channel difference exceeds 1.5/255, or when more than 0.3% of its pixels differ by more than 24 in any channel.

#### Scenario: Unchanged recipes pass verification

- **WHEN** `make sprites-verify` runs on a clean checkout on a Mac with Metal
- **THEN** it exits zero

#### Scenario: Entries not yet migrated are left alone

- **WHEN** `make sprites` runs while `catalog/building-bakery.md` still declares `source = "procedural"`
- **THEN** the committed `building-bakery*.png` files are unchanged and `make sprites-verify` does not compare them

#### Scenario: A changed recipe without re-rendered PNGs fails verification

- **WHEN** a recipe's roof finish is changed and the PNGs are not re-rendered
- **THEN** `make sprites-verify` exits non-zero and names the affected PNGs
