## ADDED Requirements

### Requirement: Figures stand on their feet and face their way

Every node that draws a walker or an animal sprite SHALL anchor at `SpriteAtlas.walkerAnchor`, the point under the feet. It SHALL show the facing that matches its direction of travel, snapped to the nearest screen diagonal. It MUST NOT mirror a sprite with a negative `xScale`, because the light is baked into the sprite.

#### Scenario: A carrier stands on its tile

- **WHEN** a carrier node is created
- **THEN** its anchor point is `SpriteAtlas.walkerAnchor` and its `xScale` is positive

#### Scenario: A stroller heading down-left faces south-west

- **WHEN** a stroller moves toward +y (screen down-left)
- **THEN** its node plays the `sw` frames with a positive `xScale`

### Requirement: Figures stand still while the game is paused

When no new simulation tick has arrived for 0.3 s, carriers and strollers SHALL show their standing frame (frame 0) and play no walk cycle. They SHALL walk again on the next tick. Asking a node for the walk cycle it already plays SHALL leave that cycle running, not restart it.

#### Scenario: A paused carrier stands on frame 0

- **WHEN** the game is paused while a carrier walks a road
- **THEN** after 0.3 s without a tick its node shows frame 0 of its facing and runs no walk action

#### Scenario: A repeated request does not restart the cycle

- **WHEN** a node that walks south-east is asked again for the south-east walk cycle
- **THEN** it keeps the walk action it has
