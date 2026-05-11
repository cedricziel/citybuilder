## ADDED Requirements

### Requirement: CloudKit private database storage
Game saves SHALL be synchronized via the user's CloudKit private database. Each save MUST be represented as a single `CKRecord` of a dedicated record type, with the save file body stored as a `CKAsset`.

#### Scenario: Save uploaded as record with asset
- **WHEN** the sync layer uploads a save for game G
- **THEN** a `CKRecord` of the configured type exists with `gameID == G` and a `body` field referencing the uploaded `CKAsset`

### Requirement: Sync triggers
The system SHALL trigger a sync upload on three events: app entering background, explicit user "Save & Sync" action, and after a successful manual save. Sync MUST also pull the latest record on app launch.

#### Scenario: Background triggers upload
- **WHEN** the app enters background with unsynced local changes
- **THEN** an upload of the most recent local save is initiated

#### Scenario: Launch pulls latest
- **WHEN** the app launches and CloudKit is available
- **THEN** the persistence layer queries CloudKit for the most recent record for any local game and merges/compares with the local save

### Requirement: Last-write-wins conflict policy v0
When local and remote save records for the same game ID differ, the system SHALL apply a last-write-wins policy based on the record's `modificationDate`. The user MUST be warned before the older save is overwritten.

#### Scenario: Newer local overwrites older remote
- **WHEN** a sync occurs and the local save was modified after the remote record
- **THEN** the local save is uploaded and replaces the remote record, after user confirmation

#### Scenario: Newer remote presented to user
- **WHEN** a sync occurs and the remote record was modified after the local save
- **THEN** the user is prompted to load the remote save or keep local before any data is overwritten

### Requirement: Current-device nudge
Each game record SHALL carry a `currentDevice` field naming the device most recently editing it. Opening a game on a different device MUST surface a non-blocking warning before allowing edits.

#### Scenario: Other-device warning shown
- **WHEN** the player opens a game whose `currentDevice` is not the current device
- **THEN** a banner reads "This game is open on <other device>. Continue here?" and the player must confirm before edits are allowed

### Requirement: Offline behavior
Sync MUST NOT block gameplay. When CloudKit is unreachable, the game SHALL continue to function with local saves only and queue a sync attempt for the next opportunity.

#### Scenario: Airplane mode plays unaffected
- **WHEN** the device is offline
- **THEN** local save, load, and gameplay continue without error and a "sync pending" indicator is shown

### Requirement: iCloud account not signed in
When no iCloud account is signed in, the system SHALL fall back to local-only persistence and surface a one-time non-blocking banner explaining sync is unavailable.

#### Scenario: No iCloud account
- **WHEN** the app launches and detects no signed-in iCloud account
- **THEN** the game runs in local-only mode and shows a dismissible "Sign in to iCloud to sync" banner

### Requirement: Sync never silently destroys data
No sync operation SHALL overwrite or delete a save without the resulting state being recoverable. The system MUST keep at least the immediately-previous local save accessible for one session as a safety net.

#### Scenario: Previous local save recoverable
- **WHEN** a remote save replaces a local save during sync
- **THEN** the replaced local save is retained as a recoverable backup until the next session ends
