## MODIFIED Requirements

### Requirement: Goals

A scenario game SHALL track a list of goals and mark each goal met once its condition holds. Goals are: reach a population, reach an age, hold a stock of a good, outgrow every rival, and the kinds in "More goal kinds". A met goal SHALL stay met. When every goal that is not a bonus goal is met, and the game is not lost, the world SHALL be won and emit `scenarioWon` once. A sandbox game SHALL have no goals and never be won.

#### Scenario: Population goal

- **WHEN** a scenario with goal "40 residents" reaches 40 residents
- **THEN** that goal is met

#### Scenario: Winning

- **WHEN** the last unmet goal becomes met
- **THEN** the world is won and that tick's events include `scenarioWon`, and later ticks do not emit it again

#### Scenario: A lost game is never won

- **WHEN** a scenario was lost to its deadline and every goal later becomes met
- **THEN** the world is not won and no `scenarioWon` event is emitted

## ADDED Requirements

### Requirement: More goal kinds

A scenario SHALL be able to use these goals besides population, age, stock and outgrowing rivals. Each SHALL be checked on the goal interval (every 10 ticks) from world state alone:

- **Buildings:** the player owns at least N operational buildings of a kind.
- **Signature project:** the player has completed a monument, or has run a gallery commission to its end, at least N times.
- **Research:** a tech is researched.
- **Treasury:** the player's balance is at least X.
- **Net income:** the player's tax minus upkeep over the last completed season is at least X.
- **Trade earnings:** the money the player has earned since the game started from selling at the town market and at rival ports is at least X. Caravan income and tax SHALL NOT count.
- **Landed by ship:** at least N units of a good have been unloaded from the player's ships into a player port on the home island since the game started.
- **Orders:** the player has fulfilled at least N orders. This kind SHALL only be used once orders exist (roadmap issue "Orders from the crown and neighbours").

The trade-earnings and landed-by-ship counters SHALL be part of the world state and SHALL survive a save and load.

#### Scenario: Building goal counts only operational buildings

- **WHEN** a scenario has the goal "own 2 windmills" and the player owns one operational windmill and one under construction
- **THEN** the goal is not met, and it is met once the second windmill is operational

#### Scenario: Research goal

- **WHEN** a scenario has the goal "research Metallurgy" and Metallurgy completes
- **THEN** that goal is met at the next goal check

#### Scenario: Trade earnings ignore tax and caravans

- **WHEN** a scenario has the goal "earn $300 from trade", the player sells 20 planks at the town market for $120 and a caravan pays $150
- **THEN** the progress reads 120 of 300

#### Scenario: Ship landings count at a home port

- **WHEN** a player ship unloads 12 ore into a player port on the home island, and later 5 ore into a player port on another island
- **THEN** the progress toward "land 30 ore at home" reads 12 of 30

#### Scenario: Net income uses the last season

- **WHEN** the last completed season paid $480 of tax and $336 of upkeep
- **THEN** the progress toward "net income $100 a season" reads 144 of 100 and the goal is met

#### Scenario: Goal counters survive a save

- **WHEN** a world that has earned $120 from trade is saved and loaded
- **THEN** the loaded world's trade earnings are $120

### Requirement: Holding goals

A goal SHALL be able to require that its condition holds for a whole season (600 ticks) rather than once. A holding goal's timer SHALL start at the first goal check where its condition holds. The timer SHALL reset whenever a goal check finds the condition false. The goal SHALL be met once the timer reaches the hold length. The timer SHALL be part of the world state.

#### Scenario: Holding resets on a dip

- **WHEN** a goal "hold 20 merchants for a season" sees 20 merchants for half a season, then 19 at one goal check, then 20 again
- **THEN** the goal is not met until 20 or more merchants have held for a full season from the second rise

#### Scenario: Holding goal is met after a season

- **WHEN** a goal "hold 20 merchants for a season" sees 20 or more merchants at every goal check for a full season
- **THEN** the goal is met and stays met when merchants later fall

### Requirement: Bonus goals

A goal SHALL be able to be marked as a bonus goal. A bonus goal SHALL be tracked and met like any other goal, SHALL NOT be needed for the win, and SHALL stop being checked once the scenario is won or lost. The number of bonus goals met when the scenario is won SHALL be its laurels.

#### Scenario: Win without the bonus

- **WHEN** a scenario has two goals and one bonus goal, and both goals are met while the bonus goal is not
- **THEN** the world is won with 0 laurels

#### Scenario: Laurels count met bonus goals

- **WHEN** a scenario with two bonus goals is won with one of them met
- **THEN** the win carries 1 laurel

### Requirement: Lose conditions

A scenario SHALL be able to have lose conditions besides bankruptcy, checked on the goal interval:

- **Deadline:** the scenario is lost when a given year starts and a goal that is not a bonus goal is still unmet.
- **Rival race:** the scenario is lost when any rival meets a given goal (age or population) before the player does. A rival's progress SHALL be measured as the player's would be.
- **Collapse:** once the player's population has reached a given floor, the scenario is lost if it falls below that floor and stays below it for a season.

When a scenario is lost, the world SHALL emit `scenarioLost` once with the reason, and SHALL stop checking goals. Unlike bankruptcy, a lost scenario SHALL NOT stop player commands, so the player can keep building in a finished game. Bankruptcy SHALL also lose a scenario and emit `scenarioLost` with the reason bankruptcy, alongside `gameOver`.

#### Scenario: Deadline passes

- **WHEN** a scenario with deadline 1206 reaches the first tick of 1206 with one goal unmet
- **THEN** that tick emits `scenarioLost` with reason deadline, and goals are no longer checked

#### Scenario: Deadline met in time

- **WHEN** a scenario with deadline 1206 has every goal met in 1205
- **THEN** the world is won and no `scenarioLost` is emitted in 1206

#### Scenario: A rival wins the race

- **WHEN** a scenario has the rival race "first to the Renaissance" and rival 2 enters the Renaissance while the player is in the Medieval age
- **THEN** that goal check emits `scenarioLost` with reason rival race, naming rival 2

#### Scenario: Collapse after a dip that lasts

- **WHEN** a scenario with collapse floor 40 reached 52 residents, then stays at 35 residents for a full season
- **THEN** the scenario is lost with reason collapse

#### Scenario: A short dip is not a collapse

- **WHEN** a scenario with collapse floor 40 reached 52 residents, falls to 35 and is back to 40 within half a season
- **THEN** the scenario is not lost

#### Scenario: Bankruptcy loses the scenario

- **WHEN** a scenario game goes bankrupt
- **THEN** that tick emits both `gameOver` and `scenarioLost` with reason bankruptcy

#### Scenario: Building goes on after a loss

- **WHEN** a scenario was lost to its deadline and the player places a house
- **THEN** the house is placed
