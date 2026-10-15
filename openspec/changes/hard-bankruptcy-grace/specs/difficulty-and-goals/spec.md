## MODIFIED Requirements

### Requirement: Difficulty

A new game SHALL have a difficulty of Easy, Normal or Hard, defaulting to Normal. The difficulty SHALL set starting money ($1,500 / $1,000 / $700), starting stock (wood, planks, food: 10/8/4, 6/5/2, 4/3/1), upkeep (75% / 100% / 125%) and bankruptcy grace (150 / 50 / 50 ticks). No grace SHALL be shorter than the tax interval, so a balance that falls below zero always sees the next tax collection before the game ends.

#### Scenario: Easy start

- **WHEN** a new game is created on Easy
- **THEN** it has $1,500 and the town center holds 10 wood, 8 planks and 4 food

#### Scenario: Hard upkeep

- **WHEN** upkeep of 4 is due on Hard
- **THEN** 5 is deducted

#### Scenario: Hard grace spans a tax interval

- **WHEN** the bankruptcy grace of each difficulty is compared with the tax interval
- **THEN** Easy, Normal and Hard give 150, 50 and 50 ticks, none shorter than the 50-tick interval
