# Citybuilder — World Style Bible

This file is the style bible for the art kit: IsoKit, which pre-renders every building, person,
animal and ship from 3D recipes (`Tools/IsoKit`), and the SVG generators that draw terrain, roads
and tile transitions (`scripts/art`). Each sprite kind also has a brief under
`Resources/Sprites.style/catalog/<id>.md` naming its sprites and its recipe.

The values below describe the kit as built. When they disagree with the IsoKit source, the source
wins and this file is corrected. `make sprites` re-renders the atlases; `make sprites-verify`
checks them against the committed PNGs and runs the content gate.

## Theme & era

A North-European coastal town that grows through the ages: half-timbered cottages and a
cobbled market plaza in the middle ages, then stone, brick and finally glass as the town moves
through the renaissance, industrial and modern ages. Three other cultures (East Asian,
Mediterranean, Middle Eastern) give every house tier and the civic buildings their own look.
Every sprite belongs to the same town, seen from the same camera and lit by the same warm
afternoon sun.

## Visual references

- Hanseatic and Low German towns: half-timbered gable houses, brick warehouses, slate and
  terracotta roofs, stone harbour walls.
- Model railway and diorama craft: readable, slightly simplified buildings whose materials still
  read as plaster, timber, thatch, stone and tile at sprite size.
- Each culture and age look takes its cues from that region's and period's vernacular building
  (courtyard houses, tiled eaves, flat roofs with parapets, mansards, glass bands), never from
  another game's art.

## Projection & scale

- **Camera.** Orthographic, Euler angles (−30°, 45°, 0): looking down at 30° from the south-east,
  so every building shows its south and east faces.
- **Scale.** One tile is 4 m; the renderer uses 64 / (4·√2) ≈ 11.3 points per metre, so a ground
  tile is a 64 × 32 point diamond.
- **Cells.** An n×n footprint renders into a cell at least 64·n points wide, with the footprint's
  bottom vertex at the cell's bottom-centre. A recipe declares its cell height; nothing it builds
  may cross the top edge.
- **Scales.** Every rendered sprite is written at `@1x` and `@2x`.

## Light rig

One rig for every render, so every building is lit the same way (`Tools/IsoKit/Sources/IsoKitCore/Rig.swift`):

- **Sun.** A directional warm light, colour (1.0, 0.80, 0.56), intensity 3000, standing up and to
  the screen's left (offset (−9, 30, 9) m from the cell's centre). It casts soft shadows (shadow
  radius 4, 16 samples) in a warm brown, (0.12, 0.08, 0.05) at 55% opacity, onto a shadow-only
  ground, so the shadow lands in the sprite's alpha.
- **Sky.** An ambient fill, colour (0.74, 0.70, 0.70), intensity 480.
- **Camera exposure.** HDR with an exposure offset of −0.15 and screen-space ambient occlusion
  (intensity 1.4, radius 0.5).
- **Night.** Recipes add no lights. Window light at night comes from separate `-lights-<n>` masks
  that light a few panes, drawn additively by the game.

## Finishes & tiers

Recipes take every surface from one finish set (`Materials.swift`), so materials match across
buildings: plaster, pale plaster, timber, rubble, ashlar, planks, thatch, thatch eave, tile, slate,
cobbles, wood, yard, rock, wheat, brick, a flat paint colour, dark window glass and blue glazing.
Textures are drawn procedurally and seeded, so a re-render reproduces them. Window glass is dark
and slightly reflective by day; nothing glows.

House tiers read as a progression in what a house is built of and how: peasant cottages under
thatch, citizen houses of stone and timber under tile, merchant houses of three storeys under
slate. The age looks climb the same way, from huts to rendered stone and courtyards, to brick
terraces and mansards, to rendered concrete with glass bands.

## Terrain

Terrain is drawn by the SVG generators in `scripts/art` and filtered linearly like the renders:

- Grass, beach, water, forest and rock ground, lit to match the sun and painted to tile without
  seams; water animates over four frames.
- Spring, autumn and winter grass, with seasonal transition sets.
- Transition tiles where grass meets beach and water, chosen by each tile's corner mask.
- Road connection tiles, including the town center's cobbled plaza.

## Animation

- **Construction.** A building's construction stages come from its recipe: usually three, from
  plinth and bare frame to walls to roof.
- **Working buildings.** Operational frames composite a moving part (sails, a saw, a wheel) over
  the idle sprite, so the frames stay coherent with the building.
- **People and animals.** Walkers, carriers and animals render in four facings with gait frames;
  ships in eight facings of two frames each.
- **In game.** Chimney smoke, fire glow, night lights and birds are drawn by the renderer, not
  baked into the sprites.

## Forbidden

- **Image-generation models.** No sprite may come from an image-generation model, as a source or
  as a reference. The goods icons still committed from the retired generative pipeline are
  replaced with SVG icons by task 4.9.
- **Lights and glow.** No recipe adds a light or a material that emits light.
- **Stray materials.** No recipe uses a material outside the shared finish set.
- **Truecolor PNGs.** Every committed atlas PNG is indexed (at most 256 colours).
