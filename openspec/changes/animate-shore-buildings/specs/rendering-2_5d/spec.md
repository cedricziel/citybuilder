## ADDED Requirements

### Requirement: Port and shipyard animate while operational

An operational port SHALL loop its facing's six operational frames, `building-port-<o>-operational-0` to `-5`, at 0.45 s each. The loop SHALL show its crane lifting a crate off the wharf, swinging it onto the quay, setting it down and swinging back out.

An operational shipyard SHALL loop its facing's five operational frames, `building-shipyard-<o>-operational-0` to `-4`:
- frames 0–2, keel and ribs, then two and four strakes, SHALL show for 2.5 s each;
- frame 3, the finished hull with six strakes, SHALL show for 4 s;
- frame 4, the empty slipway after its launch, SHALL show for 1.25 s.

An operational entry MAY give each frame its own duration. When it does, it SHALL give exactly one positive duration per frame.

#### Scenario: Cargo comes ashore at an operational port

- **WHEN** the renderer draws an operational port facing east
- **THEN** it loops `building-port-e-operational-0` to `-5`, at 0.45 s each, 2.7 s per pass

#### Scenario: The shipyard planks a hull and launches it

- **WHEN** the renderer draws an operational shipyard facing north
- **THEN** it loops `building-shipyard-n-operational-0` to `-4`
- **AND** the finished hull, frame 3, shows the longest
- **AND** the empty slipway, frame 4, shows the shortest
- **AND** one pass lasts 12.75 s
