## ADDED Requirements

### Requirement: Style bible declares the kit's visual identity

`Resources/Sprites.style/world.md` SHALL be the style bible for IsoKit and the SVG generators. It SHALL have these level-2 sections:

- `Theme & era`
- `Visual references`
- `Projection & scale`
- `Light rig`
- `Finishes & tiers`
- `Terrain`
- `Animation`
- `Forbidden`

Its camera, light and finish values MUST match the IsoKit source.

#### Scenario: Style bible declares all required sections

- **WHEN** a test parses `Resources/Sprites.style/world.md` for level-2 headings
- **THEN** the parsed set includes `Theme & era`, `Visual references`, `Projection & scale`, `Light rig`, `Finishes & tiers`, `Terrain`, `Animation` and `Forbidden`

#### Scenario: Style bible forbids image generation

- **WHEN** the `Forbidden` section of `world.md` is read
- **THEN** it forbids image-generation models as a source for any sprite

### Requirement: Catalog entry declares function, identity and recipe

Each `catalog/<id>.md` entry SHALL have the level-2 sections `Function`, `Visual identity`, `Sprites` and `Recipe`. `Sprites` lists every sprite the entry owns, one `` - `<name>` `` line each. What `Recipe` names depends on the entry:

- **Building:** the IsoKit recipe, cell height, construction stage count, and any moving part with its frame count.
- **Unit:** the IsoKit recipe, cell size, facings and frames per facing.
- **Terrain, roads and goods icons:** the SVG generator entry.
- **Pixel art:** where the committed PNG came from.

#### Scenario: Catalog entry declares all required sections

- **WHEN** a test parses any `Resources/Sprites.style/catalog/<id>.md` for level-2 headings
- **THEN** the parsed set includes `Function`, `Visual identity`, `Sprites` and `Recipe`

#### Scenario: Recipe section names a registered recipe

- **WHEN** the `Recipe` section of `catalog/building-sawmill.md` is read
- **THEN** it names the IsoKit recipe `sawmill` with a sails moving part of 4 frames

### Requirement: One rendered register for world sprites

Every catalog entry for a building (`building-*`) or unit (`walker`, `animal`, `ship`) SHALL declare `source = "isokit"` in its front matter, except the road, whose connection tiles come from the road generator and which declares `source = "svg"`. Terrain and goods-icon entries SHALL declare `source = "svg"`.

#### Scenario: Every building and unit entry is rendered by IsoKit

- **WHEN** the catalog entries whose names start with `building-` (the road aside), `walker`, `animal` or `ship` are read
- **THEN** each declares `source = "isokit"` in its front matter

#### Scenario: Terrain entries and goods icons are SVG

- **WHEN** the catalog entries whose names start with `terrain-` or `good-`, and the road's, are read
- **THEN** each declares `source = "svg"`

## REMOVED Requirements

### Requirement: Style bible declares the world's visual identity
**Reason**: Its required sections and the transparent-background scenario describe prompts for an image API.
**Migration**: "Style bible declares the kit's visual identity" replaces it, and `world.md` is rewritten as the kit's bible.

### Requirement: Master reference image anchors inter-sprite cohesion
**Reason**: Cohesion now comes from one camera, light rig and finish set (`iso-art-kit`), not from a reference image attached to API calls.
**Migration**: `master-reference.png` and `make sprites-reference` are deleted.

### Requirement: Catalog entry declares function, identity, sheet, animation
**Reason**: The `Sheet` and `Animation` sections lay out cells of a generated sheet, and there are no sheets any more.
**Migration**: "Catalog entry declares function, identity and recipe" replaces it. `Function` and `Visual identity` carry over unchanged, and `Sheet` and `Animation` become `Recipe`.

### Requirement: Sheet cells map deterministically to atlas filenames
**Reason**: `slice_plan` slices generated sheets. IsoKit writes atlas filenames directly.
**Migration**: The naming grammar in `sprite-asset-pipeline` still governs every filename IsoKit writes.

### Requirement: Prompt-hash cache controls regeneration
**Reason**: No prompts or API calls remain to cache.
**Migration**: `Resources/Sprites.style/_cache/` is deleted. Regeneration is checked by the IsoKit tolerance check.

### Requirement: Model version is pinned in the catalog
**Reason**: No image model is used.
**Migration**: The `model` key is removed from `pipeline.toml`.

### Requirement: Two-pass coherence escape hatch
**Reason**: Operational frames are composited from moving-part overlays of the same recipe, so they are coherent by construction.
**Migration**: The `two-pass` front-matter key is removed from any catalog entry that declares it.

### Requirement: One procedural register for world sprites
**Reason**: The PIL procedural register is replaced by IsoKit renders.
**Migration**: "One rendered register for world sprites" replaces it. `source = "procedural"` becomes `source = "isokit"` family by family, and the "Building register" section of `world.md` moves into `Light rig` and `Finishes & tiers`.
