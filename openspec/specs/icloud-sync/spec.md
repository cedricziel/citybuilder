# icloud-sync Specification

## Purpose
TBD - created by archiving change add-mvp-foundation. Update Purpose after archive.
## Requirements
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

### Requirement: Audio settings sync via key-value store

The CloudKit key-value store SHALL persist three keys: `audio.musicVolume` (Double, 0.0–1.0), `audio.sfxVolume` (Double, 0.0–1.0), and `audio.muted` (Bool). Changes on one device SHALL be propagated to the user's other signed-in devices using the same offline-tolerant queueing the save record sync already provides.

#### Scenario: Volume change uploads to KV store

- **WHEN** the user changes the music volume on iPad and iCloud is reachable
- **THEN** the new value is written to the CloudKit KV store under key `audio.musicVolume`

#### Scenario: Other device pulls latest volume

- **WHEN** the Mac becomes active and the CloudKit KV store contains a newer `audio.musicVolume` value
- **THEN** the Mac applies that value to its local settings before the audio engine emits its next render cycle

#### Scenario: Offline volume change queued

- **WHEN** the user changes a volume setting while the device is offline
- **THEN** the change is persisted locally and uploaded automatically when CloudKit becomes reachable

### Requirement: No iCloud account falls back to local-only audio settings

When no iCloud account is signed in, the three audio settings keys SHALL persist locally only and MUST NOT be queued for sync. The audio layer MUST function identically regardless of iCloud sign-in state.

#### Scenario: No iCloud account does not block audio

- **WHEN** the app launches with no iCloud account signed in
- **THEN** the audio engine plays normally and the volume settings persist locally across launches

### Requirement: List the user's save records

The sync layer SHALL list every save record in the user's private database, returning for each record its game ID, its modification date and its current device. A user with no records MUST get an empty list, not an error. When no iCloud account is signed in, listing MUST fail with a not-signed-in error.

#### Scenario: Listing returns every uploaded game

- **WHEN** saves for games A and B have been uploaded and the sync layer lists the user's records
- **THEN** the list holds exactly one entry for A and one for B, each with the modification date of its latest upload

#### Scenario: Listing with no records is empty

- **WHEN** the user has no save records and the sync layer lists them
- **THEN** the list is empty

#### Scenario: Listing without an account fails

- **WHEN** no iCloud account is signed in and the sync layer lists the user's records
- **THEN** the call fails with the not-signed-in error

### Requirement: Save records round-trip through the private database

A save uploaded through the sync layer SHALL be stored as one record per game in the private database, with the save body as an asset and the uploading device as the current device. Fetching the latest record for that game MUST return a byte-identical body. Uploading again for the same game MUST replace the record, not add a second one.

#### Scenario: Uploaded body fetches back unchanged

- **WHEN** a save body for game G is uploaded and the latest record for G is fetched
- **THEN** the fetched body is byte-identical to the uploaded body and its current device is the uploading device

#### Scenario: Second upload replaces the record

- **WHEN** game G is uploaded twice and the user's records are listed
- **THEN** the list holds one entry for G, dated at the second upload
