## MODIFIED Requirements

### Requirement: Time of day

The world SHALL expose a time of day derived from the tick count, with a day lasting 1,200 ticks and tick 0 falling mid-morning (0.35 of the day, where 0 is midnight): night before 0.2 and from 0.85, dawn from 0.2, day from 0.3 and dusk from 0.75. Darkness SHALL be 0 by day, 0.4 at night and change linearly through dawn and dusk.

#### Scenario: Midday is bright

- **WHEN** the tick count is 180
- **THEN** the phase is day and darkness is 0

#### Scenario: Midnight is dark

- **WHEN** the tick count is 780
- **THEN** the phase is night and darkness is 0.4
