## ADDED Requirements

### Requirement: Residents gather on the plaza

During day and dusk, each operational town center in the visible tile range SHALL show one figure on its plaza for every 3 residents of operational houses within 12 tiles, up to 8. There SHALL be none at night or below zoom 0.5. Each figure SHALL wander between spots on the plaza, the front of the footprint, and stand at each spot for a while. Its position SHALL be a pure function of the town center, its slot and the tick, and SHALL never change simulation state. With Reduce Motion on, figures SHALL stand still.

#### Scenario: Busy plaza by day
- **WHEN** a town center has houses within 12 tiles holding 30 residents at midday
- **THEN** its plaza shows 8 figures

#### Scenario: Empty plaza at night
- **WHEN** the same town is planned at midnight
- **THEN** its plaza shows no figures

#### Scenario: Figures stay on the plaza
- **WHEN** the figures are planned at any tick of a day
- **THEN** every figure stands inside the front of the town center's footprint

#### Scenario: Reduce Motion keeps figures still
- **WHEN** Reduce Motion is on
- **THEN** each figure has the same position at two ticks a minute apart
