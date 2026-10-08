## ADDED Requirements

### Requirement: Building sprites share the outline and sit on their footprint

The content gate SHALL check every building base sprite (`building-<kind>.png` and `building-<kind>-<orientation>.png`, excluding roads):

- At least 3% of its opaque pixels MUST be the outline colour `#1A1410`. Otherwise the gate fails with reason `outline_missing`.
- Its lowest opaque pixel MUST be within 1 pixel of the canvas bottom, which is where the renderer anchors the footprint's bottom vertex. Otherwise the gate fails with reason `not_grounded`.

#### Scenario: Content gate rejects a building without the outline colour

- **WHEN** the content gate inspects a building base sprite that contains no `#1A1410` pixels
- **THEN** the gate fails for that sprite with reason `outline_missing`

#### Scenario: Content gate rejects a floating building

- **WHEN** the content gate inspects a building base sprite whose lowest opaque pixel is 10 pixels above the canvas bottom
- **THEN** the gate fails for that sprite with reason `not_grounded`

#### Scenario: Committed building sprites pass outline and grounding checks

- **WHEN** the content gate inspects the committed `Resources/Buildings.atlas`
- **THEN** no building base sprite fails with `outline_missing` or `not_grounded`
