## ADDED Requirements

### Requirement: Handcarts render

A carrier with a vehicle SHALL be drawn with that vehicle's frames (`<vehicle>-<facing>-<frame>`), anchored at the carrier's feet for that vehicle, in place of its load look, and SHALL walk, pause and face like other carriers. The handcart is one person pushing a two-wheeled handcart with a generic load, in a cell that fits one road tile.

#### Scenario: A handcart shows the handcart look

- **WHEN** a carrier with a handcart is on the road
- **THEN** its node plays the handcart frames for its facing, not a load look
