## ADDED Requirements

### Requirement: Campaigns and chapters are game data

A campaigns pack SHALL define each campaign as an ordered list of chapters. A chapter SHALL define:

- an ID, a title, an intro text and an ending text;
- the layout, the seed and the start age;
- the culture, either fixed or the player's choice;
- the rival count;
- the starting money and stock per difficulty;
- the terrain directives;
- the open buildings and techs, and the techs already researched;
- its goals, bonus goals and lose conditions;
- the difficulties it can be played on;
- the reward it grants;
- its sweep configuration.

Loading SHALL reject a chapter whose goal names an unknown good, building, tech or age. It SHALL also reject an intro or ending text over 320 characters.

#### Scenario: Built-in campaigns load

- **WHEN** the game data loads
- **THEN** it holds the campaigns The Long Chronicle with 6 chapters, The Merchant Sea with 5 and Hard Ground with 4

#### Scenario: Unknown good in a goal is rejected

- **WHEN** a campaigns pack has a chapter goal "stock 20 silk" and no good named silk exists
- **THEN** loading the pack fails and names the chapter

#### Scenario: Card text over the limit is rejected

- **WHEN** a chapter's intro text is 321 characters long
- **THEN** loading the pack fails and names the chapter

### Requirement: Chapter setup

Starting a chapter at a difficulty SHALL create a new world with these properties:

- its layout, seed, start age and culture;
- exactly its rival count on an archipelago, seated by the rule for rivals in archipelago games, but taking only the first N rival islands;
- its terrain directives applied;
- its starting money and starting stock for that difficulty, in place of the difficulty's defaults;
- its pre-researched techs complete;
- its goals, bonus goals and lose conditions;
- for each age, the earliest year a rival may enter it, when the chapter sets one. A rival SHALL then need both its age's residents and that year.

A chapter SHALL NOT show the New Game "Seasonal events" toggle. Its seasonal events SHALL be on when it schedules events or leaves the random draw on (`randomEvents`), and off otherwise.

On Easy, each deadline SHALL fall a third of the chapter's span later, rounded up to a whole year. The difficulty SHALL still set upkeep, bankruptcy grace, research cost scaling and history-event odds. Two worlds started from the same chapter at the same difficulty SHALL be equal.

#### Scenario: Chronicle chapter 1 setup

- **WHEN** The Long Chronicle chapter 1 is started on Normal with the Mediterranean culture
- **THEN** the world is single-island, in Antiquity, Mediterranean, with no rivals, and its starting money, stock and goals are those of the chapter for Normal

#### Scenario: Rival count overrides the difficulty

- **WHEN** a chapter with 1 rival is started on Hard
- **THEN** the world has exactly 1 rival

#### Scenario: A rival waits for its year

- **WHEN** a chapter sets 1207 as the earliest year rivals may enter the Renaissance, and a rival has 64 residents in 1204
- **THEN** the rival stays in the Medieval age until 1207

#### Scenario: Fixed culture ignores the player's pick

- **WHEN** Hard Ground chapter 1, fixed to Northern European, is started after the player last chose East Asian
- **THEN** the world is Northern European

#### Scenario: Easy deadlines come later

- **WHEN** a chapter starting in 1200 with deadline 1206 is started on Easy
- **THEN** its deadline is 1208

#### Scenario: Chapter starts are reproducible

- **WHEN** the same chapter is started twice on Normal
- **THEN** the two worlds are equal

### Requirement: Chapter build lists

A chapter SHALL be able to close buildings that research would otherwise open, and SHALL be able to close techs. A closed building SHALL be rejected on placement as closed, and the build palette SHALL show it as unavailable with the reason "Not in this chapter". A closed tech SHALL NOT be offered for research, and SHALL NOT be researched at the start even when the start age would grant it. Buildings and techs the chapter does not close SHALL follow the normal research rules.

#### Scenario: A closed building cannot be placed

- **WHEN** a chapter closes the port and the player places a port on the shore
- **THEN** the placement is rejected as closed, and the palette shows the port as unavailable with "Not in this chapter"

#### Scenario: A closed tech is not offered

- **WHEN** a chapter closes Seafaring
- **THEN** Seafaring cannot be chosen for research

### Requirement: Chapter progression

Winning a chapter SHALL unlock the next chapter of its campaign. The first chapter of The Long Chronicle SHALL be open from the start. The first chapters of The Merchant Sea and Hard Ground SHALL open when The Long Chronicle chapter 3 is won. A won chapter SHALL record the difficulty it was won on and its laurels, and SHALL keep the best of each across wins. A lost chapter SHALL change nothing. Unlocking SHALL NOT depend on difficulty. The pack SHALL be able to mark a chapter as coming later. Such a chapter SHALL show but never open, and unlocking SHALL skip it, so winning the chapter before it opens the next chapter that is available. When a coming-later chapter becomes available, it SHALL open if the chapter before it has been won. For the best result, Hard SHALL rank above Normal and Normal above Easy, and more laurels rank above fewer, each compared on its own.

#### Scenario: Winning opens the next chapter

- **WHEN** the player wins The Long Chronicle chapter 2 on Easy
- **THEN** chapter 3 is open and chapter 2 records Easy

#### Scenario: Chronicle 3 opens the other campaigns

- **WHEN** the player wins The Long Chronicle chapter 3
- **THEN** The Merchant Sea chapter 1 and Hard Ground chapter 1 are open

#### Scenario: Unlocking skips a chapter that is coming later

- **WHEN** The Merchant Sea chapter 3 is marked coming later and the player wins chapter 2
- **THEN** chapter 4 is open and chapter 3 shows as coming later

#### Scenario: A chapter that becomes available opens

- **WHEN** the player has won The Merchant Sea chapter 2 and an update makes chapter 3 available
- **THEN** chapter 3 is open

#### Scenario: Normal outranks Easy

- **WHEN** one device has a chapter won on Normal with 0 laurels and another has it won on Easy with 0 laurels
- **THEN** the merged record shows Normal

#### Scenario: Best result is kept

- **WHEN** a chapter won on Hard with 1 laurel is later won on Easy with 2 laurels
- **THEN** it records Hard and 2 laurels

### Requirement: Campaign rewards

Each chapter SHALL name one reward: a town banner, a decor piece, or a sandbox map preset. Winning the chapter for the first time SHALL grant the reward. A map preset SHALL let a sandbox game start on that chapter's layout, seed and terrain directives with the sandbox's own difficulty, culture and rival settings, and with no goals. Rewards SHALL only add options. No sandbox option that exists before this change SHALL require a reward.

#### Scenario: A map preset reaches the sandbox

- **WHEN** the player has won Hard Ground chapter 1 and starts a sandbox game on its map preset
- **THEN** the world has that chapter's layout, seed and thinned forest, and no goals

#### Scenario: Sandbox options stay open

- **WHEN** a player who has won no chapter opens the New Game dialog
- **THEN** every culture, age, difficulty and layout offered before this change is offered

### Requirement: Campaign progress is a profile record

Campaign progress and rewards SHALL be stored in a profile record separate from world saves. Deleting a save SHALL NOT change it. The record SHALL sync through iCloud key-value storage when it is available. Two copies SHALL merge by taking every chapter won in either, the best difficulty and laurels of each, and the union of rewards.

#### Scenario: Merge keeps the best of both devices

- **WHEN** one device has won Chronicle chapters 1 and 2, and another has won chapter 1 on Hard with 2 laurels
- **THEN** the merged record has chapters 1 and 2 won, and chapter 1 shows Hard and 2 laurels

#### Scenario: Deleting a save keeps progress

- **WHEN** the player deletes the save of a won chapter
- **THEN** the chapter is still recorded as won

### Requirement: Every chapter passes its sweep

Each chapter SHALL name a sweep configuration for the PlayerBot: its first steps, mid-game order, market use and kits. The weekly sweep SHALL play every chapter from its own seed and from 9 more seeds, the seed plus 1 to 9, on the same layout and with the same directives. The chapter's guided bot SHALL win all 10 runs on Easy and at least 9 on Normal, before any lose condition fires. On Hard, the guided bot SHALL win at least 4 and at most 9 of the 10 runs, and a naive bot SHALL win at most 3 of the 10.

#### Scenario: Guided play wins every chapter

- **WHEN** the weekly sweep plays every chapter on Easy and Normal with its guided bot configuration
- **THEN** each chapter is won on all 10 Easy runs and on at least 9 of 10 Normal runs

#### Scenario: Hard stays hard

- **WHEN** the weekly sweep plays every chapter on Hard with its guided and its naive bot configurations
- **THEN** for each chapter the guided bot wins 4 to 9 of 10 runs and the naive bot wins at most 3
