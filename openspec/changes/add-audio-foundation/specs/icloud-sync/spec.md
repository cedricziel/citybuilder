## ADDED Requirements

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
