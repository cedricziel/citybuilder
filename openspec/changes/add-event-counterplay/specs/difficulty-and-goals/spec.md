## ADDED Requirements

### Requirement: Difficulty shapes seasonal events

The difficulty SHALL set the seasonal events' knobs, with these values:

| | Easy | Normal | Hard |
|---|---|---|---|
| Chance of an event in a year | 35% | 50% | 65% |
| First year with an event (year 1 is the start year) | 4th | 3rd | 3rd |
| Fires per fire event | 1 | 1 | 2 |
| Ticks before a fire spreads | 200 | 150 | 100 |
| Ticks between residents leaving with fever | 300 | 200 | 150 |
| Festival window | 2 seasons | 1 season | 1 season |
| Festival tax bonus | 15% | 10% | 10% |

The weights of the events SHALL come from each event's pack item: fire, blight and fever weigh 1, 1 and 2 on Easy, Normal and Hard, and the festival 3, 1 and 1. The warning SHALL come one season ahead on every difficulty.

#### Scenario: Easy starts events later

- **WHEN** a new Easy game starting in 1200 runs to the end of winter 1202
- **THEN** no seasonal event has been warned or started

#### Scenario: Hard fire spreads sooner

- **WHEN** a house burns on Hard with no fire watch in reach and another house's footprint touches it
- **THEN** 100 ticks after the first ignition the second house is burning

### Requirement: Event goals

A scenario or chapter SHALL be able to use two event goals.

- "No building lost to fire" SHALL be met once every fire the chapter schedules has ended and no player building has burnt down since the game started.
- "No house drops a tier during a blight" SHALL be met when a blight ends and no player house dropped a tier between its warning and its end.

Both SHALL be checked on the goal interval like the other goals.

#### Scenario: Fire goal met

- **WHEN** a chapter schedules two fires and both are put out by fire watches
- **THEN** "No building lost to fire" is met at the first goal check after the second fire ends

#### Scenario: Fire goal missed

- **WHEN** a building burns down in a chapter with the goal "No building lost to fire"
- **THEN** that goal is never met in that game

#### Scenario: Blight goal

- **WHEN** a blight ends and one merchant house dropped to citizens during the blight season
- **THEN** "No house drops a tier during a blight" is not met by that blight
