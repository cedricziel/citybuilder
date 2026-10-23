## ADDED Requirements

### Requirement: Ground macro field

The renderer SHALL draw one map-sized ground macro field over the ground tiles and under every object and building, blended `multiplyX2`, where 0.5 grey leaves the ground unchanged. The field SHALL interpolate a colour per map vertex smoothly between vertices, with at least 4 texels per tile across. The vertex colour SHALL come from:

- world-space noise that varies grass between lush and dry over several tiles and mottles it below tile size;
- a darker floor under forest;
- worn ground next to occupied tiles;
- wet sand on beach vertices next to water;
- water that is brighter next to land and darker with distance from it;
- the season.

The field SHALL be a pure function of the terrain grid, the occupied tiles and the season. The renderer SHALL rebuild it when one of them changes, and at no other time. Outside the map the field SHALL be neutral.

#### Scenario: Neighbouring grass tiles differ smoothly

- **WHEN** the macro field is built for a map of grass
- **THEN** the field colour differs between vertices several tiles apart, and no two adjacent texels differ by more than a small step

#### Scenario: Deep water is darker than shallow water

- **WHEN** the macro field is built for an island in open water
- **THEN** a water vertex next to the beach is lighter than a water vertex five tiles out

#### Scenario: Forest floor is darker than meadow

- **WHEN** the macro field is built for a map with a forest in a meadow
- **THEN** a vertex inside the forest is darker than a meadow vertex nearby

#### Scenario: Building a house wears the ground

- **WHEN** a building is placed on grass
- **THEN** the next macro field is browner at the vertices next to its footprint, and unchanged two tiles away

#### Scenario: The macro field is rebuilt only on change

- **WHEN** the scene renders frames whose terrain, occupancy and season are unchanged
- **THEN** it does not rebuild the macro field

#### Scenario: The macro field follows the season

- **WHEN** the season turns from spring to winter
- **THEN** the scene rebuilds the macro field with the winter palette

### Requirement: Grass picks a variant per tile

A full grass tile SHALL draw one of the grass variants for its season (`terrain-grass[-<season>]-v<n>`, variant 0 as the plain name), chosen by `SpriteAtlas.variantIndex` from its coordinate. Transition tiles are unchanged.

#### Scenario: Grass variants are stable per tile

- **WHEN** the same grass tile is drawn in two frames
- **THEN** it draws the same variant both times, and some of its neighbours draw other variants

### Requirement: Terrain objects on forest and mountain tiles

A forest tile SHALL draw a tree clump (`terrain-forest-<density>`), and a mountain tile a rock outcrop (`terrain-mountain-<density>`), over its ground. The variant comes from `SpriteAtlas.variantIndex`. The tile's ground SHALL be drawn as grass (or a grass transition), so forest and mountain show no tile edge of their own.

The density SHALL follow the tile's distance to the edge of its forest or rock region, counted over edge neighbours:

- distance 1: `sparse` (a forest tile may take `medium` by hash);
- distance 2: `medium`;
- distance 3 or more: `dense`. Inside a rock region, smooth world noise opens some tiles to `medium` and raises others, 4 or more from the edge, to `peak`.

A tile next to an occupied tile SHALL drop one class. An occupied tile SHALL draw no object, and an occupied forest tile SHALL still draw grass ground. A forest region reaching the map's border SHALL count the border as its edge. When a building is placed or cleared, or a tile is felled or planted, the scene SHALL redraw the objects it changes.

Objects are visual only. Simulation and placement MUST keep using each tile's own terrain.

#### Scenario: Forest edges are thinner than forest interiors

- **WHEN** the scene renders a 7 × 7 forest
- **THEN** its edge tiles draw `sparse` or `medium` clumps, and its centre tile draws a `dense` clump

#### Scenario: Trees never stand on a building

- **WHEN** a road is built on a forest tile
- **THEN** that tile draws no tree clump, and its forest neighbours drop one density class

#### Scenario: Rock thins toward the edge

- **WHEN** the scene renders a large mountain region
- **THEN** its edge tiles draw `sparse` outcrops and its interior draws `dense` or `peak` ones

#### Scenario: A forest reaching the map border

- **WHEN** a map is all forest
- **THEN** its corner tiles draw `sparse` or `medium` clumps and a tile 3 from every border draws a `dense` one

#### Scenario: A building placed in a live forest clears its clump and thins its neighbours

- **WHEN** a house is placed on a forest the scene already shows
- **THEN** the tiles under it draw grass ground and no clump, and the forest tiles next to it drop to `sparse`

#### Scenario: Felling and planting reach the scene

- **WHEN** a forest tile turns to grass, and later a grass tile beside the forest turns to forest
- **THEN** the first loses its clump and the second gains one

#### Scenario: Forest ground has no tile edge

- **WHEN** a forest tile borders a grass tile
- **THEN** both tiles draw grass ground

### Requirement: Terrain objects depth-sort with buildings

A terrain object SHALL draw just behind the global z of a 1 × 1 building on its tile, `10 + (c + r + 1) × 0.01 − 0.003 + c / (c + r + 1) × 0.0025`. Objects nearer the camera then cover buildings behind them, buildings nearer the camera cover objects behind them, and a building at the same depth always covers the object. Objects at one depth keep a fixed order by column, so overlapping neighbours never swap when the scene rebuilds.

#### Scenario: A clump in front of a house covers it

- **WHEN** a forest tile lies in front of a house (greater c + r than the house's footprint centre)
- **THEN** the tree clump's global z is greater than the house's

#### Scenario: A clump behind a house stays behind it

- **WHEN** a forest tile lies behind a house
- **THEN** the tree clump's global z is less than the house's

#### Scenario: A clump level with a building sorts behind it in every season

- **WHEN** a forest tile has the same depth as a house's footprint centre
- **THEN** the tree clump's global z is less than the house's in every season

#### Scenario: Rock and trees level with a building keep one order in every season

- **WHEN** a mountain tile and a forest tile have the same depth as a house's footprint centre
- **THEN** in every season both objects draw behind the house, and the one further right draws over the other

### Requirement: Terrain objects follow the season

Tree clumps SHALL use their `-autumn` and `-winter` sprites in those seasons. Rock outcrops SHALL use their `-winter` sprites in winter. Both SHALL use the plain sprites otherwise, and fall back to the plain sprite when a seasonal one is missing. A season change SHALL redraw every visible object.

#### Scenario: Forests turn in autumn

- **WHEN** the season turns from summer to autumn
- **THEN** every visible tree clump redraws with its `-autumn` sprite

#### Scenario: Rock keeps its look in autumn

- **WHEN** the season is autumn
- **THEN** rock outcrops draw their plain sprites

### Requirement: Scree under rock

The renderer SHALL draw one map-sized scree cover between the ground tiles and the macro field, alpha-blended. Its opacity SHALL follow the share of mountain tiles round each vertex, so it fades out across the edge of a rock region. It SHALL be rebuilt with the macro field.

#### Scenario: Scree fades at the edge of rock

- **WHEN** the cover is built for a mountain region in a meadow
- **THEN** it is opaque in the region's interior, transparent two tiles outside it, and in between at its edge

## MODIFIED Requirements

### Requirement: Terrain shows the season

Grass tiles, and the grass that forest and mountain tiles stand on, SHALL use their autumn sprites in autumn and their winter sprites in winter (`terrain-grass-autumn`, `terrain-grass-winter`, with matching variants and animation frames), and their regular sprites in spring and summer. Tiles that come into view later SHALL use the current season's sprites. A missing seasonal sprite SHALL fall back to the regular one.

#### Scenario: Winter tints grass

- **WHEN** the scene renders a snapshot dated winter
- **THEN** visible grass nodes show the winter grass sprite

#### Scenario: Summer has no tint

- **WHEN** the scene renders a snapshot dated summer
- **THEN** visible grass nodes show the regular grass sprite
