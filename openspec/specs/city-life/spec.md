# city-life Specification

## Purpose
TBD - created by archiving change add-city-life. Update Purpose after archive.
## Requirements
### Requirement: Time of day

The world SHALL expose a time of day derived from the tick count, with a day lasting 1,200 ticks and tick 0 falling mid-morning (0.35 of the day, where 0 is midnight): night before 0.2 and from 0.85, dawn from 0.2, day from 0.3 and dusk from 0.75. Darkness SHALL be 0 by day, 0.55 at night and change linearly through dawn and dusk.

#### Scenario: Midday is bright

- **WHEN** the tick count is 180
- **THEN** the phase is day and darkness is 0

#### Scenario: Midnight is dark

- **WHEN** the tick count is 780
- **THEN** the phase is night and darkness is 0.55

### Requirement: Residents have names

Each inhabited house SHALL have named residents drawn from its culture's name list, chosen from the house's ID so they stay the same across saves.

#### Scenario: Names are stable

- **WHEN** a house's resident names are read twice, once after a save round trip
- **THEN** both reads give the same names

### Requirement: Residents have wishes

A house's wish SHALL be the first need of its tier, in its culture, that is not satisfied, or none when all are satisfied.

#### Scenario: Citizen wants planks

- **WHEN** a citizens house has food but no planks
- **THEN** its wish is planks
