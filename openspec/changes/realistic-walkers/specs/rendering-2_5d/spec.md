## ADDED Requirements

### Requirement: Figures stand on their feet and face their way

Every node that draws a walker or an animal sprite SHALL anchor at `SpriteAtlas.walkerAnchor`, the point under the feet. It SHALL show the facing that matches its direction of travel, snapped to the nearest screen diagonal. It MUST NOT mirror a sprite with a negative `xScale`, because the light is baked into the sprite.

#### Scenario: A carrier stands on its tile

- **WHEN** a carrier node is created
- **THEN** its anchor point is `SpriteAtlas.walkerAnchor` and its `xScale` is positive

#### Scenario: A stroller heading down-left faces south-west

- **WHEN** a stroller moves toward +y (screen down-left)
- **THEN** its node plays the `sw` frames with a positive `xScale`
