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

The cue player SHALL keep at most one loop player per entity, so two workshops of one kind play two loops, each at its own building. When the coordinator stops an entity's loop (a stop cue, or the entity leaving the snapshot), the cue player MUST stop and detach that entity's player. At most 8 loops SHALL play at once: those whose buildings are nearest the listener, nearer first, with loops that have no position after those that do. The choice SHALL be made again whenever a loop starts or stops and whenever the listener moves.

#### Scenario: Two workshops of one kind each get a loop
- **WHEN** loops start for sawmills E1 and E2
- **THEN** both are chosen to play, keyed by E1 and E2

#### Scenario: A stop reaches the cue player
- **WHEN** the coordinator stops the loop of entity E
- **THEN** its stop handler is called with E

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
