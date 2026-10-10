## MODIFIED Requirements

### Requirement: iCloud account not signed in

When no iCloud account is signed in, the system SHALL fall back to local-only persistence. On iPhone, iPad and Mac it SHALL surface a one-time non-blocking banner explaining sync is unavailable. On Apple TV, where local saves can be deleted by the system, it SHALL instead show a notice on the title screen that reads "Sign in to iCloud to keep your cities. Without it, Apple TV may delete your progress." The notice MUST stay for as long as no account is signed in, MUST NOT be dismissible, and MUST NOT block starting or loading a game.

#### Scenario: No iCloud account

- **WHEN** the app launches on iPhone, iPad or Mac and detects no signed-in iCloud account
- **THEN** the game runs in local-only mode and shows a dismissible "Sign in to iCloud to sync" banner

#### Scenario: No iCloud account on Apple TV shows the notice

- **WHEN** the Apple TV title screen is shown and no iCloud account is signed in
- **THEN** the title screen shows the iCloud notice and New Game is still enabled

### Requirement: Last-write-wins conflict policy v0

When local and remote save records for the same game ID differ, the system SHALL apply a last-write-wins policy based on the record's `modificationDate`. The user MUST be warned before the older save is overwritten. Downloading a remote save for a game that has no local copy is not an overwrite and needs no warning.

#### Scenario: Newer local overwrites older remote

- **WHEN** a sync occurs and the local save was modified after the remote record
- **THEN** the local save is uploaded and replaces the remote record, after user confirmation

#### Scenario: Newer remote presented to user

- **WHEN** a sync occurs and the remote record was modified after the local save
- **THEN** the user is prompted to load the remote save or keep local before any data is overwritten

#### Scenario: Missing local copy downloads without a prompt

- **WHEN** a sync finds a remote record for game G and there is no local save for G
- **THEN** the remote save is written locally and the user is not prompted

## ADDED Requirements

### Requirement: Apple TV keeps saves in iCloud

On Apple TV, every save the game writes, manual or autosave, SHALL be uploaded through iCloud sync as soon as it is written and iCloud is reachable. A save that could not be uploaded MUST be retried at the next save, at launch, and when the app becomes active. At launch, before the title screen lists saved games, the Apple TV app SHALL list the user's save records and download every game that has no local copy. For a game with both copies, the last-write-wins policy applies.

#### Scenario: Autosave on Apple TV is uploaded

- **WHEN** the Apple TV app autosaves game G while iCloud is reachable
- **THEN** game G's save is uploaded

#### Scenario: Failed upload is retried at launch

- **WHEN** an upload of game G failed and the Apple TV app next launches with iCloud reachable
- **THEN** game G's save is uploaded

#### Scenario: Launch restores saves missing from caches

- **WHEN** the Apple TV app launches with no local saves and iCloud holds a save record for game G
- **THEN** game G is downloaded and is listed among the saved games before the title screen shows them
