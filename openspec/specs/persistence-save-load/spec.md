# persistence-save-load Specification

## Purpose
TBD - created by archiving change add-mvp-foundation. Update Purpose after archive.

## Requirements
### Requirement: Codable snapshot save format
A save SHALL be a single file containing the JSON-encoded `World` value plus a top-level `version` integer. The file MUST be self-describing: loaders MUST refuse to load a save whose version is unknown.

#### Scenario: Unknown version refused
- **WHEN** a save with a future `version` value is opened
- **THEN** the loader reports an error `unknown_save_version` and does not attempt to decode the body

### Requirement: Atomic write
Writing a save SHALL be atomic: failures during write MUST NOT corrupt the previous save. Implementation MUST write to a temporary file and rename on success.

#### Scenario: Crash mid-save preserves previous save
- **WHEN** the process is terminated during a save write
- **THEN** the previous save file at the destination remains intact and loadable

### Requirement: Save location
Saves SHALL be stored in the application support directory under a `saves/` subdirectory, one file per game keyed by a stable game identifier (UUID).

#### Scenario: Save path resolution
- **WHEN** the persistence layer resolves the save path for game ID G
- **THEN** the path is `<ApplicationSupport>/Citybuilder/saves/G.json`

### Requirement: Autosave
The simulation SHALL trigger an autosave on a configurable cadence (target: once per N minutes of in-game play) and whenever the app enters the background.

#### Scenario: Autosave on backgrounding
- **WHEN** the app transitions from active to background
- **THEN** an autosave is requested for the current game before suspension

### Requirement: Manual save and load UI
The UI SHALL expose explicit "Save", "Save As", and "Load" actions on platforms where they are appropriate. A new game and a load-game flow MUST be reachable from the main menu.

#### Scenario: Manual save creates file
- **WHEN** the player taps Save with a current game
- **THEN** a save file at the resolved path is written and confirmed to the user

### Requirement: Save versioning and forward migration
Each save SHALL include a numeric `version`. When a save with an older known version is loaded, the persistence layer MUST apply registered migration steps in order to produce a current-version `World` before the game starts.

#### Scenario: Older save migrated forward
- **WHEN** a save with version N is loaded into a build supporting version N+M
- **THEN** the loader applies the M migration steps in order and the game starts in a valid state

### Requirement: Save integrity check
On load, the persistence layer SHALL validate the decoded `World` for structural integrity (e.g. tile coordinates in bounds, building references resolve). On failure, the load MUST abort with a diagnostic and the previous game state MUST be preserved.

#### Scenario: Corrupt save reports error
- **WHEN** a tampered save with out-of-bounds tile coordinates is loaded
- **THEN** the loader reports an error and the previous in-memory game state is preserved
