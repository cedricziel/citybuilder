## ADDED Requirements

### Requirement: Every workshop has a work loop

The shipped bindings SHALL give every building kind that has a production recipe, except the monument, a loop cue on the `loop` bus, filtered to that kind. The cue SHALL be bound to both `productionCycleCompleted` and `productionResumed`, so a workshop's loop starts with its first finished cycle and again after a stall. `productionStalled` SHALL be bound to a stop cue for every kind.

#### Scenario: Every producing kind has a loop
- **WHEN** the shipped bindings are loaded
- **THEN** for each kind with a production recipe other than the monument, `productionCycleCompleted` and `productionResumed` each have a looping cue filtered to that kind, and `productionStalled` has a stop cue that matches it

#### Scenario: A workshop's loop starts with its first cycle
- **WHEN** a bakery that never stalled completes its first production cycle
- **THEN** the coordinator starts the bakery's loop once, and later cycles start no second loop

### Requirement: Loop players follow their buildings

The cue player SHALL keep at most one loop player per entity, so two workshops of one kind play two loops, each at its own building. When the coordinator stops an entity's loop (a stop cue, or the entity leaving the snapshot), the cue player MUST stop and detach that entity's player. At most 8 loops SHALL play at once: those whose buildings are nearest the listener, nearer first, with loops that have no position after those that do. A playing loop SHALL count as 3 tiles nearer than it is, so a loop that is not playing replaces it only when clearly nearer. The choice SHALL be made again whenever a loop starts or stops and whenever the listener moves. A loop SHALL fade in when it starts and fade out before its player is released, over 0.25 seconds.

#### Scenario: Two workshops of one kind each get a loop
- **WHEN** loops start for sawmills E1 and E2
- **THEN** both are chosen to play, keyed by E1 and E2

#### Scenario: A stop reaches the cue player
- **WHEN** the coordinator stops the loop of entity E
- **THEN** its stop handler is called with E

#### Scenario: A stopped loop's player is released
- **WHEN** entity E's loop starts twice, is stopped, and starts again
- **THEN** one voice played, was stopped and released, and the restart made a new voice

#### Scenario: Moving the listener re-chooses the loops
- **WHEN** ten loops play near tile (0, 0) and the listener moves to (20, 0)
- **THEN** the nearest loop to the old spot stops and the farthest starts

#### Scenario: A demolished workshop's loop stops
- **WHEN** a sawmill's loop plays and the next snapshot no longer holds the sawmill
- **THEN** its voice is stopped and released

#### Scenario: A playing loop holds its place near the boundary
- **WHEN** a playing loop is 10 tiles away and one that is not playing is 9 tiles away, with room for one loop
- **THEN** the playing loop keeps playing, and only when it is 14 tiles away does the nearer one replace it

#### Scenario: Only the nearest loops play
- **WHEN** ten loops want to play, at distances 1 through 10 tiles from the listener
- **THEN** the 8 nearest are chosen, and when the listener moves next to the farthest, it is chosen instead of the one now farthest away

### Requirement: Stop cues need no bus

A cue whose `action` is `stop` plays nothing, so it MAY leave out `bus`. Every other cue MUST name its bus. The shipped bindings MUST decode; a document that fails to decode silences every cue.

#### Scenario: Shipped bindings decode with bus-less stop cues
- **WHEN** the shipped `bindings.json`, whose `productionStalled` stop cues have no `bus`, is loaded against the shipped manifest
- **THEN** it decodes, and its stop cues have the `stop` action

#### Scenario: A start cue without a bus is rejected
- **WHEN** a start cue in a bindings document leaves out `bus`
- **THEN** decoding fails

### Requirement: A session's loops end with it

When the player leaves a game (Quit to Title, or a new game or load replacing it), the title screen SHALL end the game session, and the app shell SHALL then stop every building loop through `AudioStack.endSession()`. The coordinator SHALL forget its active loops and cached snapshot, so a new game that reuses entity IDs starts its loops afresh. Music and the ambient bed SHALL keep playing.

#### Scenario: A session's loops end with it
- **WHEN** a sawmill's loop plays and the session ends
- **THEN** its voice is stopped, and in the next game a sawmill with the same entity ID starts a new loop

#### Scenario: Returning to the title ends the session
- **WHEN** the player returns to the title from a game
- **THEN** the game session's end handler runs exactly once

### Requirement: A broken audio document is reported

When the bundle holds `manifest.json` or `bindings.json` but the file fails to load, `AudioBundleLoader` SHALL report the error, as a fault in the system log by default, and then fall back to an empty document. A missing file SHALL fall back silently, as before.

#### Scenario: A broken bindings file is reported
- **WHEN** the bundle's `bindings.json` has a start cue without a bus
- **THEN** the loader reports one error naming `bindings.json` and returns empty bindings
