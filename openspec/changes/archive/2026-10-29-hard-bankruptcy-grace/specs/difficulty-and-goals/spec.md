## MODIFIED Requirements

### Requirement: Difficulty

A new game SHALL have a difficulty of Easy, Normal or Hard, defaulting to Normal. The difficulty SHALL set starting money ($1,500 / $1,000 / $700), starting stock (wood, planks, food: 10/8/4, 6/5/2, 4/3/1), upkeep (75% / 100% / 125%) and bankruptcy grace (150 / 50 / 50 ticks). No grace SHALL be shorter than the tax interval, and the game SHALL end only once the balance has been below zero for more ticks than the grace, so a balance that falls below zero on a collection tick always sees the next collection.

#### Scenario: Easy start

- **WHEN** a new game is created on Easy
- **THEN** it has $1,500 and the town center holds 10 wood, 8 planks and 4 food

#### Scenario: Hard upkeep

- **WHEN** upkeep of 4 is due on Hard
- **THEN** 5 is deducted

#### Scenario: Hard grace spans a tax interval

- **WHEN** the bankruptcy grace of each difficulty is compared with the tax interval
- **THEN** Easy, Normal and Hard give 150, 50 and 50 ticks, none shorter than the 50-tick interval

#### Scenario: A dip on a collection tick sees the next collection

- **WHEN** on Hard the balance falls below zero on a collection tick and the next collection, 50 ticks later, lifts it to zero or above
- **THEN** the game does not end
