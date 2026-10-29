## ADDED Requirements

### Requirement: Event losses are not shortages

Residents who leave with fever and residents lost when a house burns down SHALL NOT count as an unmet need, and SHALL NOT change a house's short-interval counts (the decline grace). A house that is spared by a physician or outside the fever's district SHALL advance and decline by the ordinary rules. Shortages caused by blight SHALL count as ordinary shortages.

#### Scenario: Fever leaves the grace alone

- **WHEN** a merchant house with all needs met loses a resident to fever
- **THEN** none of its needs has a short-interval count, and it does not drop a tier

#### Scenario: Blight shortage counts

- **WHEN** a blight leaves the network of a peasant house without food at its consumption
- **THEN** its food short-interval count grows by one, as for any shortage

### Requirement: Festivals speed advancement near the market

While a festival runs, a player house within the reach of an operational player marketplace SHALL move up one tier after its next tier's needs have been met for 60 consecutive ticks instead of 120, and SHALL pay the difficulty's festival tax bonus. Other houses SHALL follow the ordinary rules.

#### Scenario: Festival house advances sooner

- **WHEN** a full peasant house in reach of the marketplace has food and planks for 60 ticks during a festival
- **THEN** the house becomes citizens
