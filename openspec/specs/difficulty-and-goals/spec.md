# difficulty-and-goals Specification

## Purpose
TBD - created by archiving change add-difficulty-and-goals. Update Purpose after archive.
## Requirements
### Requirement: Difficulty

A new game SHALL have a difficulty of Easy, Normal or Hard, defaulting to Normal. The difficulty SHALL set starting money ($1,500 / $1,000 / $700), starting stock (wood, planks, food: 10/8/4, 6/5/2, 4/3/1), upkeep (75% / 100% / 125%) and bankruptcy grace (150 / 50 / 30 ticks).

#### Scenario: Easy start

- **WHEN** a new game is created on Easy
- **THEN** it has $1,500 and the town center holds 10 wood, 8 planks and 4 food

#### Scenario: Hard upkeep

- **WHEN** upkeep of 4 is due on Hard
- **THEN** 5 is deducted

### Requirement: Difficulty shapes history events

History events SHALL fire with a 50% chance each year on Easy and Normal and 65% on Hard. Rats in the granary SHALL never be drawn on Easy and SHALL be twice as likely as each other event on Hard.

#### Scenario: Easy has no rats

- **WHEN** the events of years 1201 to 1400 are decided on Easy
- **THEN** none of them is rats in the granary

### Requirement: Goals

A scenario game SHALL track a list of goals — reach a population, reach an age, hold a stock of a good — and mark each goal met once its condition holds. When every goal is met the world SHALL be won and emit `scenarioWon` once. A sandbox game SHALL have no goals and never be won.

#### Scenario: Population goal

- **WHEN** a scenario with goal "40 residents" reaches 40 residents
- **THEN** that goal is met

#### Scenario: Winning

- **WHEN** the last unmet goal becomes met
- **THEN** the world is won and that tick's events include `scenarioWon`, and later ticks do not emit it again

### Requirement: Built-in scenarios

The game SHALL offer three scenarios: First Harvest (Antiquity, Easy: 40 residents and 20 bread in store), The Guild Town (Medieval, Normal: 30 merchant residents and 30 tools in store) and Steam and Smoke (Renaissance, Hard: reach the Industrial age).

#### Scenario: First Harvest setup

- **WHEN** a new game is created from First Harvest
- **THEN** it is in Antiquity on Easy with goals 40 residents and 20 bread
