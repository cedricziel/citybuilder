## ADDED Requirements

### Requirement: First-hour guide

The game screen SHALL show a "First steps" guide while all of these hold: the in-game date is in the game's first year, at least one step is open, the game is not over, and the player has not hidden the guide this session. It SHALL show in every game mode and difficulty. The guide SHALL list three steps in this order:

1. "Build 3 houses on a road", met once the player owns at least 3 operational houses.
2. "Earn more tax than upkeep", met once one collection's tax is at least its upkeep, as `World.playerTaxAndUpkeep` reports them, while the player owns at least 3 operational houses.
3. "Sell surplus at the market", met once the player has sold at least one unit at a town center market in this session.

A met step SHALL stay met for the rest of the session. The guide SHALL show the tax, the upkeep and the net (tax minus upkeep) of one collection as they stand, and SHALL mark the net as negative when it is below zero. The guide SHALL NOT pause the simulation or take input focus, and SHALL offer a control that hides it for the rest of the session.

#### Scenario: Guide shows on a new game

- **WHEN** a session starts on a new game at tick 0
- **THEN** the guide shows with all three steps open and the simulation is not paused

#### Scenario: Guide tracks the houses step

- **WHEN** the player owns 2 operational houses and a third house finishes construction
- **THEN** the "Build 3 houses on a road" step is met

#### Scenario: Tax step needs houses

- **WHEN** the player owns 1 operational house and one collection's tax is at least its upkeep
- **THEN** the "Earn more tax than upkeep" step is still open

#### Scenario: Guide shows the ledger

- **WHEN** one collection's tax is $12 and its upkeep is $36
- **THEN** the guide shows tax $12, upkeep $36 and a negative net of $24

#### Scenario: Market step met by a sale

- **WHEN** the player sells 5 planks at the town center market
- **THEN** the "Sell surplus at the market" step is met

#### Scenario: Hiding the guide

- **WHEN** the player hides the guide
- **THEN** the guide does not show again in that session

#### Scenario: Guide leaves after year one

- **WHEN** the in-game date reaches the second year with a step still open
- **THEN** the guide does not show

#### Scenario: Guide leaves when every step is met

- **WHEN** the last open step is met
- **THEN** the guide does not show

### Requirement: Tool strip names buildings that pay no tax

While a building that pays no tax is armed and the player owns fewer than 3 operational houses, the tool strip caption SHALL add the building's difficulty-scaled upkeep for one collection and the words "pays no tax". Arming a house, or arming any building once the player owns 3 operational houses, SHALL leave the caption as it is today.

#### Scenario: Caption warns before houses

- **WHEN** the player owns 1 operational house and arms the lumberjack hut
- **THEN** the tool strip caption names the hut's upkeep and says it pays no tax

#### Scenario: Caption unchanged for houses

- **WHEN** the player owns 1 operational house and arms the house
- **THEN** the tool strip caption is the same as without this requirement
