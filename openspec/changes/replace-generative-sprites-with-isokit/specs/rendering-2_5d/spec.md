## ADDED Requirements

### Requirement: Terrain transitions from corner terrain

The renderer SHALL derive a terrain for every map vertex from the tiles that share it. Of `water`, `beach` and `grass`, the vertex takes the lowest-ranked present (water < beach < grass). Where a tile's corners include both `grass` and `water`, its `grass` corners SHALL be treated as `beach`.

A tile whose corners hold exactly two terrains of a declared pair SHALL draw `terrain-<upper>-<lower>-t<mask>`, where the mask bits (N=1, E=2, S=4, W=8) mark the corners holding the upper terrain. All other tiles keep their existing sprite and variant selection.

The derivation is visual only. Simulation and placement rules MUST keep using each tile's own `TerrainKind`.

#### Scenario: Grass meeting beach picks a transition tile

- **WHEN** a grass tile's south and west neighbours are beach and its other neighbours are grass
- **THEN** the renderer draws a `terrain-grass-beach-t<mask>` tile whose mask marks the north and east corners only

#### Scenario: Grass beside water shows a beach edge

- **WHEN** a grass tile borders a water tile directly
- **THEN** its corners shared with the water tile are treated as beach, it draws a `grass-beach` transition, and the water tile draws a `beach-water` transition

#### Scenario: Transitions do not change gameplay

- **WHEN** a grass tile is drawn as a `grass-beach` transition
- **THEN** placement on that tile follows the rules for grass

### Requirement: World textures are @2x and linearly filtered

Terrain, building, unit and ship textures SHALL be loaded from atlases that include `@2x` images and SHALL use `.linear` filtering. Goods icons and status overlay badges SHALL keep `.nearest` filtering. Sprite sizes in points and every anchor and position rule are unchanged.

#### Scenario: Building textures filter linearly

- **WHEN** the renderer creates the node for an operational house
- **THEN** its texture's `filteringMode` is `.linear` and its size in points matches the @1x PNG

#### Scenario: Goods icons stay pixel art

- **WHEN** the HUD shows the wood icon
- **THEN** its texture's `filteringMode` is `.nearest`
