## ADDED Requirements

### Requirement: Walker variants share one lookup

`SpriteAtlas.walkerAnimation(facing:variant:)` SHALL return the frames of every people variant. `variant` SHALL default to the worker, so a call without it returns the worker's frames. The walker entry in `SpriteAnimation` SHALL declare 8 frames at 0.1 s per frame, looping. Frame 0 SHALL work as the idle pose. `SpriteAtlas.catalogSpriteNames` SHALL list every variant, facing and frame.

#### Scenario: The default variant is the worker

- **WHEN** `walkerAnimation(facing: .se)` and `walkerAnimation(facing: .se, variant: .worker)` are called
- **THEN** both return the 8 textures `walker-se-0` … `walker-se-7`

#### Scenario: Every walker frame is catalogued

- **WHEN** `catalogSpriteNames` is read
- **THEN** it contains `walker-<variant>-<facing>-<frame>` for every variant, all four facings and frames 0–7, and each of those names resolves to a texture

### Requirement: A good maps to a carrier look

`SpriteAtlas.WalkerVariant.carrying(_:)` SHALL map every good to a carrier variant:

- wood and planks to logs
- beer and wine to barrel
- bread, ore, charcoal, iron and tools to crate
- every other good to sack

#### Scenario: Goods map to their family

- **WHEN** `carrying` is asked for `.wood`, `.wine`, `.tools` and `.grain`
- **THEN** it answers `.carrierLogs`, `.carrierBarrel`, `.carrierCrate` and `.carrierSack`

### Requirement: Animal lookup

`SpriteAtlas.animalAnimation(_:facing:)` SHALL return the frames of an animal action: sheep and cow walk (8 frames) and graze (4 frames), and the hen's peck (4 frames). Each comes from its `SpriteAnimation` entry.

#### Scenario: Sheep grazing has four frames

- **WHEN** `animalAnimation(.sheepGraze, facing: .sw)` is called
- **THEN** it returns `animal-sheep-graze-sw-0` … `-3`
