## ADDED Requirements

### Requirement: Handcarts render

A carrier with a handcart SHALL be drawn as one person pushing a two-wheeled handcart with a generic load (`handcart-<facing>-<frame>`), in place of its load look, in a cell that fits one road tile. It SHALL walk, pause and face like other carriers.

#### Scenario: A handcart shows the handcart look

- **WHEN** a carrier with a handcart is on the road
- **THEN** its node plays the handcart frames for its facing, not a load look
