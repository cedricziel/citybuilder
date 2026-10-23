## ADDED Requirements

### Requirement: Residents gather on the plaza

During day and dusk, each operational town center in the visible tile range SHALL show one figure on its plaza for every 3 residents of operational houses within 12 tiles, up to 8. There SHALL be none at night or below zoom 0.5. Each figure SHALL wander between open spots on the plaza and stand at each spot for a while. No figure SHALL stand on or walk through the plaza's props (well, stalls, barrels, crate) or the building, and no two figures of one plaza SHALL stand on the same spot. A figure SHALL draw just above its town center in depth order, so buildings in front of the plaza cover it. Figures SHALL stop their walk cycle when the game is paused. Its position SHALL be a pure function of the town center, its slot and the tick, and SHALL never change simulation state. With Reduce Motion on, figures SHALL stand still. Each figure SHALL be a worker or a woman, chosen by a hash of its town center and slot, and SHALL be drawn without a tint.

#### Scenario: Busy plaza by day
- **WHEN** a town center has houses within 12 tiles holding 30 residents at midday
- **THEN** its plaza shows 8 figures

#### Scenario: Empty plaza at night
- **WHEN** the same town is planned at midnight
- **THEN** its plaza shows no figures

#### Scenario: Figures stay on the plaza
- **WHEN** the figures are planned at any tick of a day
- **THEN** every figure stands inside the town center's footprint and outside its props

#### Scenario: Reduce Motion keeps figures still
- **WHEN** Reduce Motion is on
- **THEN** each figure has the same position at two ticks a minute apart

#### Scenario: A mixed crowd
- **WHEN** a plaza shows 8 figures
- **THEN** each figure's look is a pure function of its town center and slot, both looks appear, and no figure is tinted
