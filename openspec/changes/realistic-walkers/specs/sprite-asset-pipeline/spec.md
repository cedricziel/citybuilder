## ADDED Requirements

### Requirement: Walker and animal sprite names

Walker and animal sprites SHALL follow these grammars, and every one of them SHALL route to the `Kit` atlas:

- Residents: `walker-[woman-]<facing>-<frame>.png`. Without `woman`, the name is the worker. `<facing>` is one of `ne`, `nw`, `se`, `sw`, and `<frame>` is 0–7.
- Carriers: `carrier-<load>-<facing>-<frame>.png`, where `<load>` is `sack`, `crate`, `barrel` or `logs` (the `CarrierLoad` families of `add-carrier-glide`), with the same facings and frames.
- Grazing animals: `animal-<kind>-<action>-<facing>-<frame>.png`, where `<kind>` is `sheep` or `cow`, `<action>` is `walk` (frames 0–7) or `graze` (frames 0–3), and `<facing>` is as above.
- Hens: `animal-hen-<facing>-<frame>.png`, with frames 0–3.

#### Scenario: Worker and variant names route to Kit

- **WHEN** `SpriteAtlasRouting.atlasName(for:)` is asked for `walker-se-3`, `walker-woman-nw-7` and `carrier-logs-nw-7`
- **THEN** it answers `Kit` for each

#### Scenario: Animal names route to Kit

- **WHEN** `SpriteAtlasRouting.atlasName(for:)` is asked for `animal-sheep-graze-sw-2` and `animal-hen-ne-0`
- **THEN** it answers `Kit` for both

### Requirement: Walker and animal sprite inventory

Walker sprites SHALL be 24×30 points (48×60 pixels @2x), with their feet 2 points above the bottom edge, at the horizontal centre. Every resident look and carrier load SHALL have 8 frames in each of the four facings. Each animal SHALL have its full frame set in each of the four facings. The sprites SHALL be rendered by IsoKit under the shared light rig, as the buildings are, and ship @1x and @2x. The `Units` atlas is retired: people and ships route to `Kit`.

#### Scenario: Walker frames have the walker size

- **WHEN** the content gate inspects `walker-woman-se-0.png` and `walker-woman-se-0@2x.png`
- **THEN** they are 24×30 and 48×60 pixels

#### Scenario: Every variant and facing has eight gait frames

- **WHEN** `Kit.atlas` is enumerated
- **THEN** `walker-<facing>-0` … `-7`, `walker-woman-<facing>-0` … `-7` and `carrier-<load>-<facing>-0` … `-7` exist for every load and every facing

#### Scenario: A missing gait frame fails the gate

- **WHEN** `carrier-sack-nw-5.png` is missing from a migrated walker atlas
- **THEN** the gate fails with reason `walker_frames_missing` and names that file
