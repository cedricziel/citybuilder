## ADDED Requirements

### Requirement: The town issues festival orders

The order board SHALL accept a third issuer, the town, which SHALL issue orders only for a festival (`seasonal-events`). A town order SHALL be accepted, declined, dispatched and fulfilled like a crown order, and delivered to a town center. It SHALL NOT count toward the limit of 2 accepted orders or the board's 3 offers. It SHALL NOT change any favour, and SHALL NOT count toward the "fulfil N orders" goal. Missing or declining it SHALL cost nothing.

#### Scenario: A festival beside two crown orders

- **WHEN** the player has 2 accepted crown orders and the town issues a festival
- **THEN** the player can accept both festival orders

#### Scenario: A missed festival costs no favour

- **WHEN** an accepted festival order passes its deadline unfilled with crown favour 4
- **THEN** crown favour is still 4 and the treasury is unchanged
