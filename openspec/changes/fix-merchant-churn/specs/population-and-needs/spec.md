## ADDED Requirements

### Requirement: Houses move up one at a time per hub

After a house moves up into a tier, no other house served by the same market hub SHALL move up into that tier for the next 100 ticks. A house that meets its next tier's needs while another house of its hub has just moved up into that tier SHALL wait, ready, and move up on the first tick the 100 ticks have passed, as long as it still meets the needs. Of several waiting houses of one hub, the one with the lowest entity ID SHALL move up first. Moving down a tier SHALL NOT be held back, and SHALL NOT hold back other houses. The ticks since a house last moved up SHALL be saved with it; a save without them SHALL load as if the house moved up long ago.

#### Scenario: A stocked hub moves one house up per interval

- **WHEN** six full citizen houses are served by a town center holding 40 of every merchant need, for 180 ticks and then for 100 more
- **THEN** one house is merchants after the first 180 ticks and two after the next 100

#### Scenario: The oldest waiting house moves up first

- **WHEN** three full citizen houses share a stocked town center for 180 ticks
- **THEN** the house built first is merchants and the second is still citizens

#### Scenario: A waiting house moves up as soon as its turn comes

- **WHEN** two full citizen houses share a stocked town center
- **THEN** the second becomes merchants exactly 100 ticks after the first

#### Scenario: A decline does not hold up the next advance

- **WHEN** a house of a stocked town center has just come down to citizens and another full citizen house waits for 125 ticks
- **THEN** one of the two houses has become merchants
