## ADDED Requirements

### Requirement: Walker and animal sprite names

Walker and animal sprites SHALL follow these grammars, and every one of them SHALL route to the `Kit` atlas:

- People: `walker-[<variant>-]<facing>-<frame>.png`. `<variant>` is one of `woman`, `carrier-sack`, `carrier-crate`, `carrier-barrel` or `carrier-logs`; without it, the name is the worker. `<facing>` is one of `ne`, `nw`, `se`, `sw`, and `<frame>` is 0–7.
- Grazing animals: `animal-<kind>-<action>-<facing>-<frame>.png`, where `<kind>` is `sheep` or `cow`, `<action>` is `walk` (frames 0–7) or `graze` (frames 0–3), and `<facing>` is as above.
- Hens: `animal-hen-<facing>-<frame>.png`, with frames 0–3.

#### Scenario: Worker and variant names route to Kit

- **WHEN** `SpriteAtlasRouting.atlasName(for:)` is asked for `walker-se-3` and `walker-carrier-logs-nw-7`
- **THEN** it answers `Kit` for both

#### Scenario: Animal names route to Kit

- **WHEN** `SpriteAtlasRouting.atlasName(for:)` is asked for `animal-sheep-graze-sw-2` and `animal-hen-ne-0`
- **THEN** it answers `Kit` for both

### Requirement: Walker and animal sprite inventory

Walker sprites SHALL be 24×30 points (48×60 pixels @2x), with their feet 2 points above the bottom edge, at the horizontal centre. Every people variant SHALL have 8 frames in each of the four facings. Each animal SHALL have its full frame set in each of the four facings. The sprites SHALL be rendered by IsoKit under the shared light rig, as the buildings are, and ship @1x and @2x. `Units.atlas` SHALL hold no `walker-` sprite.

#### Scenario: Walker frames have the walker size

- **WHEN** the content gate inspects `walker-woman-se-0.png` and `walker-woman-se-0@2x.png`
- **THEN** they are 24×30 and 48×60 pixels

#### Scenario: Every variant and facing has eight gait frames

- **WHEN** `Kit.atlas` is enumerated
- **THEN** `walker-<facing>-0` … `-7` and `walker-<variant>-<facing>-0` … `-7` exist for every variant and every facing

#### Scenario: A missing gait frame fails the gate

- **WHEN** `walker-carrier-sack-nw-5.png` is missing from a migrated walker atlas
- **THEN** the gate fails with reason `walker_frames_missing` and names that file
