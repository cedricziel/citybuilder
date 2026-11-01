## MODIFIED Requirements

### Requirement: Order size follows the town's output

For a template, the recent output SHALL be the spare output of its good over the last up to 4 closed seasons: the units the player's producers made plus the units bought at the market, less the units used by production (recipe inputs and fuel), used by construction and sold at the market. Units the houses used SHALL still count. A season that used more than it made counts against the others. The template is eligible only when at least one season is closed and the recent output is above zero; a good the town uses up is not offered at all, at any minimum. The quantity SHALL be `recent × seasons × size / (closed × 100)`, rounded down, where `seasons` and `size` are the template's, then times the difficulty's size percent (Easy 80, Normal 100, Hard 120) over 100 rounded down, then at most the template's maximum and at most 75% of what the player's stores can hold of the good (the sum of their capacities for it), rounded down. For a crown order the stores are the town centers and the stores whose road network reaches one; for a rival's order, whose goods go by ship, they are all the player's operational stores. A template whose quantity is below its minimum SHALL NOT be eligible.

The deadline SHALL be the tick `window` seasons after the issue, where `window` is the template's seasons times the difficulty's window percent (Easy 130, Normal 100, Hard 85) over 100, rounded to the nearest whole season and at least 1; the order is on time through that tick. The board shows it as the date of the season in which the window ends. The reward SHALL be `quantity × base price × reward percent / 100`, rounded down.

#### Scenario: Size follows recent output

- **WHEN** a Normal town made 120 planks over its last 4 seasons, and the crown's timber template (2 seasons, size 90, minimum 12, maximum 80, reward 125) is issued
- **THEN** the order asks for 54 planks, and its reward is $540

#### Scenario: Size is capped by the stores

- **WHEN** the same town's stores hold at most 60 planks together
- **THEN** the order asks for 45 planks

#### Scenario: Size is capped by the template

- **WHEN** a town made 400 planks over its last 4 seasons
- **THEN** the timber order asks for 80 planks

#### Scenario: Difficulty scales the size and the time

- **WHEN** the same orders are issued on Hard and on Easy
- **THEN** the Hard order asks for 64 planks and has a 2-season window (2 × 85%, rounded), and the Easy order asks for 43 planks and has a 3-season window (2 × 130%, rounded)

#### Scenario: Too little output is not asked for

- **WHEN** a town made 10 planks over its last 4 seasons
- **THEN** the timber template is not eligible

#### Scenario: Size follows spare output

- **WHEN** a Normal town made 60 planks and bought 5 in each of its last 4 seasons, and used 30 in workshops, 10 for building, 15 in houses and sold 5 in each
- **THEN** its recent output is 80 planks, and the crown's timber order asks for 36

#### Scenario: Output the town uses up is not asked for

- **WHEN** a town's lumberjack huts cut 60 wood in each of its last 4 seasons and its sawmills used all 60
- **THEN** no wood template is eligible

#### Scenario: A season that drew on its stock counts against the window

- **WHEN** a town made 30 planks in each of its last 3 seasons and used 100 for building in the season before them, making none
- **THEN** its recent output is below zero and the timber template is not eligible
