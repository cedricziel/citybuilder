## ADDED Requirements

### Requirement: Identical one-shots are rate-limited

A one-shot's cue is its file together with the binding key it was dispatched for: the event's case name, or `ui.<name>` for an interface sound. The cue player SHALL NOT start a one-shot whose cue started less than 50 ms earlier, or has already started 6 times in the last second. A one-shot held back this way SHALL be dropped, not deferred. Each cue is limited on its own, so two events bound to the same file don't hold each other back. Loops, music and ambient beds MUST NOT be limited. The coordinator still dispatches one cue per event; the limit applies where the cue player starts it.

#### Scenario: A burst in one frame plays once

- **WHEN** 100 cues for the same one-shot file are dispatched in one frame
- **THEN** the file starts once

#### Scenario: Spaced cues all play

- **WHEN** the same one-shot is dispatched every 200 ms for one second
- **THEN** every one of them starts

#### Scenario: At most six a second

- **WHEN** the same one-shot is dispatched every 60 ms for one second
- **THEN** 6 of them start

#### Scenario: Different cues don't hold each other back

- **WHEN** two different one-shot files are dispatched in the same frame, or one file for two different events (`ageAdvanced` and `rivalAgeAdvanced` share a peal)
- **THEN** both start

### Requirement: One-shot starts never back up

A pool node already running in the engine's current run SHALL take its next one-shot without being stopped and started again: after its last cue when that has ended, cutting it off when not. Only a node not running in the current run is started. The cue player SHALL drop a one-shot while the same cue still waits on the node queue; different cues are never dropped for waiting. A one-shot queued before the engine stopped or started again SHALL be dropped when its turn comes, not played in the new run.

#### Scenario: A busy node is not restarted

- **WHEN** a one-shot goes to a node that runs in the current run and still plays an earlier cue
- **THEN** the node takes the new cue, cutting off the earlier one, without a stop or a start

#### Scenario: A burst restarts each node at most once

- **WHEN** 100 different one-shot files are dispatched in one frame to a bus of 4 nodes while the node queue is held
- **THEN** every one of them is scheduled, and the node queue starts a node at most 4 times

#### Scenario: A waiting cue holds back the same cue

- **WHEN** the same cue is dispatched three times while the node queue is held
- **THEN** it plays once

#### Scenario: A restart drops cues queued before it

- **WHEN** a one-shot waits on the node queue and the engine is stopped and started again before its turn
- **THEN** the one-shot is dropped and no node is started for it

### Requirement: Voice start and stop are idempotent

A voice (a building loop or a music track) SHALL schedule its file and start its node only on its first start, and SHALL fade out, stop and detach its node only on its first stop. A voice that has stopped MUST NOT start again.

#### Scenario: A second start does nothing

- **WHEN** a looping voice is started twice
- **THEN** its file is scheduled twice, as for one start, and its node is started once

#### Scenario: A second stop does nothing

- **WHEN** a voice is stopped twice
- **THEN** its node is stopped and detached once

### Requirement: One-shots play in one format

Every one-shot asset SHALL be mono or stereo, at any sample rate. The cue player SHALL convert each one-shot, when it first loads it, to the pool's format: 44.1 kHz stereo, a mono asset playing from both channels. Every pool node is connected in that format, so cues of different source formats can share a node. A test SHALL load every one-shot in the shipped bindings and fail on one that doesn't convert.

#### Scenario: Different formats share a node

- **WHEN** a mono 44.1 kHz one-shot plays on a pool node and a stereo 48 kHz one-shot plays next on the same node
- **THEN** both are scheduled on the running node, and nothing traps

#### Scenario: A shipped one-shot in an unexpected format is caught

- **WHEN** a one-shot in the shipped bindings has more than two channels or doesn't read
- **THEN** the shipped-asset test fails, naming the file
