## ADDED Requirements

### Requirement: One-shots don't cut off long sounds

A one-shot SHALL play on the next node of its bus's pool, in rotation, that is not still playing. When every node is still playing, it SHALL take the node that finishes soonest among those playing a cue of 1.5 seconds or less, and only when every node plays a longer cue SHALL it take the one that finishes soonest.

#### Scenario: A free node is used
- **WHEN** node 0 is still playing and node 1 is free, and the rotation is at node 0
- **THEN** the one-shot plays on node 1

#### Scenario: A long peal is not cut off
- **WHEN** every node is busy, node 0 with a 4-second peal ending in 3 seconds and nodes 1–3 with short clinks ending later than that
- **THEN** the one-shot takes the short clink that ends soonest, and the peal plays on

### Requirement: Every bound key is a real event

Every key in the shipped `bindings.json` SHALL either name a `WorldEvent` case as `AudioCoordinator` reports it, or start with `ui.` for an interface sound.

#### Scenario: Bound keys are event names
- **WHEN** the shipped bindings are loaded
- **THEN** each key is a case key the coordinator produces for some event, or an interface sound name
