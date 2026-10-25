## ADDED Requirements

### Requirement: Identical one-shots are rate-limited

The cue player SHALL NOT start a one-shot whose file started less than 50 ms earlier, or whose file has already started 6 times in the last second. A one-shot held back this way SHALL be dropped, not deferred. Each file is limited on its own. Loops, music and ambient beds MUST NOT be limited. The coordinator still dispatches one cue per event; the limit applies where the cue player starts it.

#### Scenario: A burst in one frame plays once

- **WHEN** 100 cues for the same one-shot file are dispatched in one frame
- **THEN** the file starts once

#### Scenario: Spaced cues all play

- **WHEN** the same one-shot is dispatched every 200 ms for one second
- **THEN** every one of them starts

#### Scenario: At most six a second

- **WHEN** the same one-shot is dispatched every 60 ms for one second
- **THEN** 6 of them start

#### Scenario: Different files don't hold each other back

- **WHEN** two different one-shot files are dispatched in the same frame
- **THEN** both start

### Requirement: One-shot starts never back up

The cue player SHALL drop a one-shot while 4 one-shots already wait on the node queue. A one-shot queued before the engine stopped or started again SHALL be dropped when its turn comes, not played in the new run.

#### Scenario: A burst restarts each node at most once

- **WHEN** 100 different one-shot files are dispatched in one frame to a bus of 4 nodes
- **THEN** the node queue starts a node at most 4 times

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
