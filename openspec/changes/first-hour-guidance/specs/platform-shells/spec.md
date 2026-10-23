## ADDED Requirements

### Requirement: First-hour guide

The game screen SHALL show a "First steps" guide while all of these hold: at least one step is open, the game is not over, the player has not hidden the guide this session, and the session has not seen every step met. It SHALL show in every game mode and difficulty, with no time limit. The guide SHALL list five steps in this order:

1. "Build a farm", met when the player owns an operational farm.
2. "Make planks: a lumberjack and a sawmill", met when the player owns an operational lumberjack hut and an operational sawmill.
3. "Build 3 houses on a road", met when the player owns at least 3 operational houses with a road beside them.
4. "Earn more tax than upkeep", met when one collection's tax, as `World.playerTaxAndUpkeep` reports it, is more than its upkeep.
5. "Sell surplus at the market", met when the player has sold at least one unit at a town center market this season.

A step SHALL count as met when the world meets it as it stands, so a loaded save shows the steps its world meets, and SHALL then stay met for the rest of the session. Buildings of other owners SHALL NOT count. Each step SHALL carry one line saying why it matters: farms feed residents, a house needs planks, residents pay tax, tax against upkeep decides the treasury, and the market turns surplus into cash; a line that names a gesture SHALL use the platform's verb: "Tap" on iPhone and iPad, "Click" on the Mac, "Select" on Apple TV.

The guide SHALL show the tax, the upkeep and the net (tax minus upkeep) of one collection as they stand, and SHALL mark the net as negative when it is below zero. The guide SHALL NOT pause the simulation or take input focus, and SHALL offer a control that hides it for the rest of the session. On a screen narrower than 600 points or shorter than 500 points the guide SHALL collapse to one line with the count of met steps and the net, which expands when activated; assistive technologies SHALL hear the collapsed line as the count and the net in words, and SHALL be able to expand and collapse it.

#### Scenario: Guide shows on a new game

- **WHEN** a session starts on a new game at tick 0
- **THEN** the guide shows with all five steps open and the simulation is not paused

#### Scenario: Farm step met by a farm

- **WHEN** a farm the player placed finishes construction
- **THEN** the "Build a farm" step is met

#### Scenario: Planks step needs both buildings

- **WHEN** the player owns an operational lumberjack hut and no sawmill
- **THEN** the "Make planks" step is still open

#### Scenario: Guide tracks the houses step

- **WHEN** the player owns 2 operational houses on a road and a third house on a road finishes construction
- **THEN** the "Build 3 houses on a road" step is met

#### Scenario: Houses off the road don't count

- **WHEN** the player places 3 houses with no road beside them and they finish construction
- **THEN** the "Build 3 houses on a road" step is still open

#### Scenario: Rival buildings don't count

- **WHEN** a rival owns an operational farm, lumberjack hut, sawmill and 3 houses on a road, and the player owns none
- **THEN** every step of the player's guide is open

#### Scenario: Tax step needs more tax than upkeep

- **WHEN** one collection's tax equals its upkeep
- **THEN** the "Earn more tax than upkeep" step is still open

#### Scenario: Guide shows the ledger

- **WHEN** one collection's tax is $12 and its upkeep is $36
- **THEN** the guide shows tax $12, upkeep $36 and a negative net of $24

#### Scenario: Market step met by a sale

- **WHEN** the player sells 5 planks at the town center market
- **THEN** the "Sell surplus at the market" step is met

#### Scenario: Market step stays met after the season

- **WHEN** the player sold at the market and a new season resets the market ledger
- **THEN** the "Sell surplus at the market" step is still met

#### Scenario: Hiding the guide

- **WHEN** the player hides the guide
- **THEN** the guide does not show again in that session

#### Scenario: Guide stays past year one

- **WHEN** the in-game date reaches the second year with a step still open
- **THEN** the guide still shows

#### Scenario: Guide leaves when every step is met

- **WHEN** the last open step is met
- **THEN** the guide does not show again in that session

#### Scenario: Loaded save shows its steps

- **WHEN** a session starts on a save whose player owns an operational farm, lumberjack hut and sawmill
- **THEN** the guide shows the farm and planks steps as met

#### Scenario: Guide collapses on short screens

- **WHEN** the game screen is 844 by 390 points
- **THEN** the guide shows as its one-line form

### Requirement: Tool strip warns while the guide shows

While the first-hour guide shows, the tool strip caption SHALL add a warning to the armed building's hint: for a house while the player owns no operational farm, "No farm yet: residents need food"; for any building with upkeep, "Upkeep <amount> per collection", the difficulty-scaled upkeep of one collection the building would pay at its candidate site, with any culture upkeep relief there, written as the HUD writes money. When the guide does not show, or neither case applies, the caption SHALL be the same as without this requirement.

#### Scenario: Caption warns about food

- **WHEN** the guide shows, the player owns no operational farm and arms the house
- **THEN** the tool strip caption ends with "No farm yet: residents need food"

#### Scenario: Caption names upkeep

- **WHEN** the guide shows on Hard and the player arms the sawmill
- **THEN** the tool strip caption ends with the sawmill's Hard upkeep per collection

#### Scenario: Caption unchanged without the guide

- **WHEN** the player has hidden the guide and arms the house with no farm
- **THEN** the tool strip caption is the same as without this requirement
## MODIFIED Requirements

### Requirement: Deficit hint

The first time in a session that the treasury is below zero, the game screen SHALL show the deficit hint as its banner: on the tick that emits `bankruptcyWarning`, or when the session starts with the treasury already below zero and the game not over. On the tick it shows, the hint SHALL take the place of any other banner that tick raises. Its title SHALL be "In the red: upkeep $<upkeep> vs tax $<tax>", with the upkeep and tax of one collection as they stand when it shows. Its description SHALL read "Residents pay tax only when fed. Build a farm, fill your houses, and sell surplus at the town center's market."

While the hint shows, the simulation SHALL be paused without opening the pause menu, so the bankruptcy grace does not run down. The hint SHALL stay until the player dismisses it, with its Resume button, with the pause control or, on the Mac, with Esc; dismissing it resumes the simulation. On Apple TV the Resume button SHALL take focus when the hint shows. The hint SHALL show at most once per session, and the game-over banner SHALL take its place once the game is over.

#### Scenario: Deficit hint names the cause

- **WHEN** a tick emits `bankruptcyWarning` while one collection's upkeep is $14 and its tax is $9
- **THEN** the session shows a banner titled "In the red: upkeep $14 vs tax $9" that names food, houses and the market

#### Scenario: Deficit hint pauses until dismissed

- **WHEN** the deficit hint shows and the session is stepped 100 times
- **THEN** the tick count does not change and the hint still shows, and after the player dismisses it the next step advances the tick

#### Scenario: Deficit hint wins its tick

- **WHEN** a tick emits `bankruptcyWarning` and a history event together
- **THEN** the session shows the deficit hint, not the history event

#### Scenario: Deficit hint on loading a save in the red

- **WHEN** a session starts on a world whose treasury is below zero and whose game is not over
- **THEN** the session shows the deficit hint and is paused

#### Scenario: Deficit hint shows once

- **WHEN** the player dismisses the hint and a later tick emits `bankruptcyWarning` again in the same session
- **THEN** no deficit hint shows
