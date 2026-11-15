## MODIFIED Requirements

### Requirement: Autosave
The game SHALL autosave into the game's one save slot, so Continue loads it, when the app leaves the foreground or is about to terminate, at each season change, and after five minutes of wall-clock play since the last autosave attempt. The triggers SHALL live outside the simulation, which MUST NOT read the wall clock. An autosave SHALL NOT run for a town that has not yet ticked, a bankrupt town, a lost scenario, or a UI-test seeded launch, and SHALL be skipped when the town has not changed since the last successful autosave.

The snapshot SHALL be taken on the main actor; encoding and writing SHALL run off it on a serial queue. A trigger that arrives while a write runs SHALL coalesce into at most one further write with a fresh snapshot, and two writes MUST NOT run at once. Leaving the foreground SHALL write before it returns. A failed autosave MUST leave the previous save and backup unchanged and SHALL be reported to the player.

#### Scenario: Season change saves
- **WHEN** a played town crosses into a new season
- **THEN** its save slot holds that town

#### Scenario: Interval saves after five minutes
- **WHEN** 299 seconds pass, then one more, while the game steps
- **THEN** no autosave runs at 299 seconds and one runs at 300

#### Scenario: Triggers coalesce
- **WHEN** three triggers arrive while an autosave is being written
- **THEN** exactly one more autosave follows, with the newest snapshot, and no two writes overlap

#### Scenario: Leaving the foreground has written
- **WHEN** the app leaves the foreground
- **THEN** the save slot holds the current town before the request returns

#### Scenario: Finished games are not autosaved
- **WHEN** a trigger fires for a bankrupt town, a lost scenario, an unplayed town or a seeded UI-test world
- **THEN** no file is written and the slot is unchanged

#### Scenario: Unchanged town is not rewritten
- **WHEN** a trigger fires and the town's tick equals the last autosaved tick
- **THEN** no file is written

#### Scenario: Failed autosave keeps the old save
- **WHEN** an autosave write fails
- **THEN** the previous save file is byte-identical, the failure is reported, and the next trigger tries again

## ADDED Requirements

### Requirement: Autosave backup and load fallback
Before an autosave replaces the save, the save SHALL be kept as one backup file next to it (`<id>.json.bak`), but only when it still decodes. Loading a game whose save cannot be read or decoded SHALL load the backup instead when one exists, and otherwise report the save's own error. The backup MUST NOT appear in the list of saves.

#### Scenario: Backup holds the previous autosave
- **WHEN** three autosaves run
- **THEN** the save holds the third and the backup holds the second

#### Scenario: Corrupt save falls back
- **WHEN** the save file is corrupt and a backup exists
- **THEN** Continue loads the backup's town

#### Scenario: Corrupt save never replaces a good backup
- **WHEN** an autosave runs while the save file is corrupt
- **THEN** the backup still holds the earlier good town

#### Scenario: No backup, corrupt save
- **WHEN** the save file is corrupt and no backup exists
- **THEN** the load fails with the save's error

## MODIFIED Requirements

### Requirement: Atomic write
Writing a save SHALL be atomic: failures during write MUST NOT corrupt the previous save. Implementation MUST write to a temporary file and replace the destination in one step (no remove-then-move), and MUST remove its temporary file on failure.

#### Scenario: Crash mid-save preserves previous save
- **WHEN** the process is terminated during a save write
- **THEN** the previous save file at the destination remains intact and loadable

#### Scenario: Failed write leaves the old file
- **WHEN** the temporary file cannot be written
- **THEN** the destination still holds its previous content
