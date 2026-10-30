## ADDED Requirements

### Requirement: Handcarts render

A carrier with a vehicle SHALL be drawn with that vehicle's frames (`<vehicle>-<facing>-<frame>`), anchored at the carrier's feet for that vehicle, in place of its load look, and SHALL walk, pause and face like other carriers. The handcart is one person pushing a two-wheeled handcart with a generic load, in a cell that fits one road tile.

#### Scenario: A handcart shows the handcart look

- **WHEN** a carrier with a handcart is on the road
- **THEN** its node plays the handcart frames for its facing, not a load look

### Requirement: Market porters render

A market porter SHALL be drawn with the porter frames (`porter-<facing>-<frame>`), a figure carrying two baskets on a shoulder yoke, in place of a load look, and SHALL walk, pause and face like other carriers. On the way back to its hub it SHALL be drawn with the empty-basket frames (`porter-empty-<facing>-<frame>`). Idle porters at a hub SHALL NOT be drawn.

#### Scenario: A loaded porter shows full baskets

- **WHEN** a porter is on its way to a house
- **THEN** its node plays the porter frames for its facing

#### Scenario: Full baskets read at game zoom

- **WHEN** a loaded porter is drawn at zoom 1 over grass or a road
- **THEN** each basket shows a heaped load in warm, light colours that stand clear of the grass, the road and the wicker, and rises above the basket rim

#### Scenario: A returning porter shows empty baskets

- **WHEN** a porter is on its way back to its hub
- **THEN** its node plays the empty-basket porter frames for its facing

### Requirement: The marketplace renders in the world's culture

The renderer SHALL draw an operational marketplace with `building-marketplace`, or with `building-marketplace-<culture>` where the world's culture has its own look, anchored at the footprint's bottom vertex like other buildings.

#### Scenario: An East Asian marketplace uses its culture's look

- **WHEN** the renderer builds the sprite for an operational marketplace in an East Asian world
- **THEN** the node's texture is `building-marketplace-east-asian`
