## ADDED Requirements

### Requirement: Campaigns on the title screen

The title screen SHALL offer a Campaigns entry next to New Game. It SHALL open the chapter select screen, which lists each campaign with its chapters. A chapter SHALL show as locked, open or won. A won chapter SHALL show its best difficulty and its laurels. A locked chapter SHALL name what opens it. Choosing an open or won chapter SHALL offer the difficulties the chapter allows, and the culture picker when the chapter leaves the culture to the player.

#### Scenario: Locked chapter names its key

- **WHEN** the player opens chapter select with only The Long Chronicle chapter 1 won
- **THEN** chapter 2 shows as open, chapter 3 as locked with "Win chapter 2", and The Merchant Sea chapter 1 as locked with "Win The Long Chronicle chapter 3"

#### Scenario: Fixed culture hides the culture picker

- **WHEN** the player chooses Hard Ground chapter 2
- **THEN** no culture picker is shown, and the chapter names its culture

### Requirement: Chapter intro and ending cards

Starting a chapter SHALL show its intro card, with the chapter title, its illustration, the intro text and the goal list. The simulation SHALL stay paused while the card is open. Winning SHALL show the ending card in place of the plain win sheet, with the ending text, the laurels earned and the reward granted, and an action to go to the next chapter. A lost chapter SHALL show a short lost card with the reason, and actions to retry or keep building. The cards SHALL follow the Claude Design canvas approved for them.

#### Scenario: Intro pauses the game

- **WHEN** a chapter starts
- **THEN** its intro card is shown and the game does not tick until the card is closed

#### Scenario: Ending card offers the next chapter

- **WHEN** a tick emits `scenarioWon` in The Long Chronicle chapter 2
- **THEN** the session shows the chapter's ending card with an action to start chapter 3

#### Scenario: Lost card names the reason

- **WHEN** a tick emits `scenarioLost` with reason deadline
- **THEN** the session shows the lost card reading "The year turned before the goals were met"

### Requirement: Goals panel shows bonus goals and limits

In a chapter game, the goals panel SHALL list the bonus goals under their own heading, and SHALL show any deadline as the years left. It SHALL also show any rival race with the leading rival's progress next to the player's.

#### Scenario: Deadline readout

- **WHEN** a chapter with deadline 1206 is in the summer of 1204
- **THEN** the goals panel reads "1 year, 2 seasons left"

#### Scenario: Rival race readout

- **WHEN** a chapter has the race "first to the Renaissance" and the leading rival has 50 of the 60 residents its age gate needs
- **THEN** the goals panel shows that rival's progress as 50/60 next to the player's
