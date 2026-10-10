## ADDED Requirements

### Requirement: Apple TV keeps saves in iCloud

On Apple TV, every save that the game writes, manual or autosave, SHALL also be uploaded through iCloud sync as soon as iCloud is reachable. At launch, before the title screen lists saved games, the Apple TV app SHALL download any save records that are newer than, or missing from, the local caches copy. A save that exists only in the caches copy MUST be uploaded at the next opportunity, not discarded.

#### Scenario: Autosave on Apple TV is uploaded

- **WHEN** the Apple TV app autosaves game G while iCloud is reachable
- **THEN** an upload of game G's save record is queued

#### Scenario: Launch restores saves missing from caches

- **WHEN** the Apple TV app launches with an empty caches directory and iCloud holds a save record for game G
- **THEN** game G is downloaded into caches and appears in the title screen's list of saved games

### Requirement: Apple TV warns when saves cannot be kept

When no iCloud account is signed in on Apple TV, the game SHALL still be playable, and the title screen SHALL show a persistent notice that reads "Sign in to iCloud to keep your cities. Without it, Apple TV may delete your progress." The notice MUST stay visible for as long as no account is signed in, and MUST NOT block starting or loading a game.

#### Scenario: No iCloud account on Apple TV shows the notice

- **WHEN** the Apple TV app shows the title screen and no iCloud account is signed in
- **THEN** the title screen shows the iCloud notice and New Game is still enabled
