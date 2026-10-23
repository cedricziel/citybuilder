## ADDED Requirements

### Requirement: Terrain transitions from corner terrain

The renderer SHALL derive a terrain for every map vertex from the up to four tiles that share it, counting `forest` and `mountain` as `grass`:

- When those tiles include both `grass` and `water`, the vertex SHALL be `beach`.
- Otherwise the vertex takes the lowest-ranked terrain present (water < beach < grass).

A tile whose corners hold exactly two terrains of a declared pair SHALL draw `terrain-<upper>-<lower>-t<mask>`, where the mask bits (N=1, E=2, S=4, W=8) mark the corners holding the upper terrain. All other tiles keep their existing sprite and variant selection.

The derivation is visual only. Simulation and placement rules MUST keep using each tile's own `TerrainKind`.

A transition SHALL win over the seasonal sprite. In autumn and winter a `grass-beach` transition SHALL draw `terrain-grass-beach-t<mask>-<season>` when the atlas has it, else the plain transition. A season change SHALL redraw every tile with a grass corner, whatever its own terrain.

#### Scenario: Shores follow the season

- **WHEN** the season turns from spring to autumn on a map where grass meets beach
- **THEN** every `grass-beach` transition on screen, including those on beach tiles, is redrawn from the `-autumn` set

#### Scenario: Grass meeting beach picks a transition tile

- **WHEN** a grass tile's south and west neighbours are beach and its other neighbours are grass
- **THEN** the renderer draws a `terrain-grass-beach-t<mask>` tile whose mask marks the north and east corners only

#### Scenario: Grass beside water shows a beach edge

- **WHEN** a grass tile borders a water tile directly
- **THEN** the two vertices the tiles share are beach, the grass tile draws a `grass-beach` transition with its two far corners as grass, and the water tile draws a `beach-water` transition with its two far corners as water

#### Scenario: Transitions do not change gameplay

- **WHEN** a grass tile is drawn as a `grass-beach` transition
- **THEN** placement on that tile follows the rules for grass

### Requirement: Roads join their neighbours

An operational road SHALL draw the connection sprite for its mask: an arm per paved edge neighbour and a corner where two adjacent arms and the diagonal between them are paved. Paved means a road or the town center's footprint. A road touching the town center, edge-on or diagonally, SHALL draw the cobbled `plaza` set; every other road the worn-earth set. The connection is part of the sprite key, so placing or demolishing a neighbour redraws the road. The derivation is visual only.

#### Scenario: A straight road joins both neighbours
- **WHEN** a road has road neighbours at -x and +x only
- **THEN** it draws `building-road-c5`

#### Scenario: A 2x2 block of road closes in the middle
- **WHEN** four roads form a 2×2 block
- **THEN** each draws its two inward arms and the corner between them, so the block has no hole

#### Scenario: The starter ring paves up to the town center
- **WHEN** a road in the town center's starter ring is drawn
- **THEN** it draws the `plaza` set with arms into the town center's footprint

### Requirement: World textures are @2x and linearly filtered

Terrain, building, unit and ship textures and the goods icons SHALL be loaded from atlases that include `@2x` images and SHALL use `.linear` filtering. Status overlay badges SHALL keep `.nearest` filtering. Sprite sizes in points and every anchor and position rule are unchanged.

#### Scenario: Building textures filter linearly

- **WHEN** the renderer creates the node for an operational house
- **THEN** its texture's `filteringMode` is `.linear` and its size in points matches the @1x PNG

#### Scenario: Goods icons filter linearly

- **WHEN** the texture for the wood icon is looked up
- **THEN** its `filteringMode` is `.linear`

#### Scenario: Status badges stay pixel art

- **WHEN** the texture for the waiting-materials badge is looked up
- **THEN** its `filteringMode` is `.nearest`

#### Scenario: Linear and nearest textures never share an atlas

- **WHEN** a sprite name is routed to its atlas
- **THEN** it goes to the `Kit` atlas exactly when its texture filters linearly, because SpriteKit applies one filtering mode to a whole atlas page

### Requirement: Stocks row of goods icons

The HUD's stocks row SHALL render one chip per good with non-zero stock OR non-zero capacity on the current island. Each chip MUST display the good's icon (loaded from `Kit.atlas`) and the integer count. Goods with both zero stock AND zero capacity MUST be omitted to keep the row uncluttered.

#### Scenario: Stocks row shows goods present on the island

- **WHEN** the current island has 12 wood and 4 planks in its stockpile
- **THEN** the HUD renders two chips: a wood chip with "12" and a planks chip with "4"

#### Scenario: Goods with zero stock and zero capacity are omitted

- **WHEN** an island has warehouses storing wood and planks but no capacity at all for food
- **THEN** the food chip is not rendered

#### Scenario: Goods icon scales smoothly

- **WHEN** a good icon is rendered at any scale
- **THEN** SwiftUI's `Image.interpolation(.high)` is applied, as the icons are anti-aliased SVG renders

## REMOVED Requirements

### Requirement: Stocks row layout

**Reason**: It loaded the icons from `Icons.atlas` with nearest-neighbour interpolation, for pixel art.

**Migration**: "Stocks row of goods icons" keeps the layout, loads the SVG icons from `Kit.atlas` and scales them smoothly.
