## ADDED Requirements

### Requirement: Birds cross the sky

By day and at dusk, with Reduce Motion off, the scene SHALL launch a flock of 5–9 dark, code-drawn birds across the view at intervals of 40–90 s of scene time, with at most one flock in the air. Each bird SHALL flap and cast a faint shadow. When the visible tiles include a water tile next to land and the zoom is at least 0.5, three white gulls SHALL circle over one such tile. There SHALL be no birds at night or with Reduce Motion on. Birds SHALL never change simulation state.

#### Scenario: A flock crosses by day
- **WHEN** the scene time passes the next flock time at midday
- **THEN** the bird layer holds a flock of 5 to 9 birds moving across the view

#### Scenario: No birds at night or with Reduce Motion
- **WHEN** the scene renders at midnight, or with Reduce Motion on
- **THEN** the bird layer is empty

#### Scenario: Gulls wheel over the coast
- **WHEN** a visible water tile borders land at midday and zoom 1
- **THEN** three gulls circle over a coastal water tile
