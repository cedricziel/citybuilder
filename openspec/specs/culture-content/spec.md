# culture-content Specification

## Purpose
TBD - created by archiving change add-culture-content. Update Purpose after archive.
## Requirements
### Requirement: Each culture has a luxury

Each culture SHALL have a luxury good made by a garden and a producer only that culture can build: Northern European hops → beer (hop garden, brewery), Mediterranean grapes → wine (vineyard, winery), East Asian tea leaves → tea (tea garden, tea house), Middle Eastern coffee cherries → coffee (coffee grove, roastery). Gardens SHALL produce 1 raw good every 40 ticks; producers SHALL turn 2 raw goods into 1 luxury every 50 ticks.

#### Scenario: Winery makes wine

- **WHEN** an operational winery holds 2 grapes
- **THEN** it produces 1 wine after 50 ticks

#### Scenario: Luxury per culture

- **WHEN** each culture's luxury is read
- **THEN** they are beer, wine, tea and coffee for Northern European, Mediterranean, East Asian and Middle Eastern

### Requirement: Culture-only buildings

A building tied to a culture SHALL be rejected for placement with `wrongCulture` in a world of another culture.

#### Scenario: No vineyards in the north

- **WHEN** a Northern European world places a vineyard
- **THEN** the placement is rejected as belonging to the Mediterranean culture

### Requirement: Cultivation unlocks the luxury chain

The Medieval tech Cultivation (50 knowledge, no prerequisites) SHALL unlock every culture's garden and producer.

#### Scenario: Brewery needs Cultivation

- **WHEN** a new Northern European game places a brewery before Cultivation
- **THEN** the placement is rejected as locked by Cultivation
