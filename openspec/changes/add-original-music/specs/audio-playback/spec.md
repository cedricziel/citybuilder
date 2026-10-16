## ADDED Requirements

### Requirement: Original music is composed and rendered in the repository

The game's original music SHALL be written as text scores in `scripts/audio/music/` and rendered by its offline synthesizer into mono IMA4 files under `Resources/Audio/music/`, using no recorded samples. Rendering MUST be deterministic: the same scores SHALL produce byte-identical files on every machine, so `make music-check` can compare them.

The shipped bindings SHALL:
- bind a title theme;
- give every season at least one game track whose tags include it or that has none.

Each original piece SHALL have a manifest entry by "Citybuilder original score", under CC0, whose title marks it as original and generated in the repository.

#### Scenario: Regenerating reproduces the committed music
- **WHEN** `make music-check` renders every score
- **THEN** each result is byte-identical to the committed file, and the check exits 0

#### Scenario: Music covers the menu and every season
- **WHEN** the shipped bindings are loaded
- **THEN** a title theme is bound, and each season has a game track that suits it

#### Scenario: Original music is credited
- **WHEN** the shipped manifest is loaded
- **THEN** every file under `music/` other than `bards-tale.m4a` has an entry by "Citybuilder original score" whose title says it is original and generated in-repo
