## ADDED Requirements

### Requirement: Walker variants share one lookup

`SpriteAtlas.walkerAnimation(facing:look:)` SHALL return the frames of every resident look (`worker`, `woman`), and `walkerAnimation(facing:)` SHALL return the worker's. Carriers keep `carrierAnimation(load:facing:)`. The walker and carrier entries in `SpriteAnimation` SHALL declare 8 frames at 0.1 s per frame, looping. Frame 0 SHALL work as the idle pose. `SpriteAtlas.catalogSpriteNames` SHALL list every look, load, facing and frame.

#### Scenario: The default variant is the worker

- **WHEN** `walkerAnimation(facing: .se)` and `walkerAnimation(facing: .se, look: .worker)` are called
- **THEN** both return the 8 textures `walker-se-0` … `walker-se-7`

#### Scenario: Every walker frame is catalogued

- **WHEN** `catalogSpriteNames` is read
- **THEN** it contains every `walker-[woman-]<facing>-<frame>` and `carrier-<load>-<facing>-<frame>` for all four facings and frames 0–7, and each of those files is committed where it routes

### Requirement: Animal lookup

`SpriteAtlas.animalAnimation(_:facing:)` SHALL return the frames of an animal action (`AnimalAction`): sheep and cow walk (8 frames) and graze (4 frames), and the hen's peck (4 frames). Each comes from its `SpriteAnimation` entry, and `AnimalAction.anchor` is the point under the animal's feet, as the animal brief lists it.

#### Scenario: Sheep grazing has four frames

- **WHEN** `animalAnimation(.sheepGraze, facing: .sw)` is called
- **THEN** it returns `animal-sheep-graze-sw-0` … `-3`
