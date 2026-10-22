## ADDED Requirements

### Requirement: Terrain object sprites

Terrain objects SHALL be named `terrain-<kind>-<density>[-<season>][-v<variant>]`:

- `<kind>` is `forest` or `mountain`.
- `<density>` is `sparse`, `medium` or `dense` for forest, and `sparse`, `medium`, `dense` or `peak` for mountain.
- `<season>` is `autumn` or `winter` for forest, and `winter` for mountain.
- `<variant>` is 1 to 3; variant 0 is the name without the slot.

Every name SHALL exist at @1x and @2x in `Resources/Kit.atlas` and filter linearly. Each sprite SHALL be 144 × 132 points with the tile centre 56 points from its left edge and 112 points from its top. It SHALL carry its own ground shadow, and nothing in it may reach below the tile's bottom vertex by more than the shadow's softness.

#### Scenario: Object names route to the Kit atlas

- **WHEN** the routing test resolves `terrain-forest-dense-autumn-v2`
- **THEN** it routes to the Kit atlas with linear filtering, under the stem `terrain-forest-dense-autumn`

#### Scenario: Every object sprite ships

- **WHEN** the content gate checks the Kit atlas
- **THEN** every density, season and variant above exists at both scales

### Requirement: Terrain objects are generated deterministically

`art.flora` and `art.rocks` SHALL generate the object sprites from seeded geometry, ray-cast on the CPU and lit with `art.ground`'s rig, with no network, no GPU and no image model. Two runs SHALL produce byte-identical raw renders. A clump's trees, and an outcrop's stones, SHALL depend only on the density and variant, so each season shows the same trees.

#### Scenario: Tree clumps are repeatable

- **WHEN** a tree clump is rendered twice
- **THEN** both renders are byte-identical

#### Scenario: Seasons keep the same trees

- **WHEN** a clump is rendered in spring and in autumn
- **THEN** its trunks stand at the same positions in both

### Requirement: Grass variants join every neighbour

`art.ground` SHALL draw 4 grass variants per season. A variant SHALL differ from the shared tile-periodic texture only inside a window that is zero on the tile's edges, so any two variants join without a seam.

#### Scenario: Variants share their edges

- **WHEN** two grass variants are rendered
- **THEN** their texels on every tile edge are identical
