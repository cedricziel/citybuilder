## ADDED Requirements

### Requirement: Game-over banner and tools

While the game is over, the game screen SHALL show a banner titled "Bankrupt" that says the treasury stayed in the red too long and that the player can still save from the pause menu, or quit to the title to load a save or start a new game. The banner MUST NOT expire and MUST take the place of any other banner. It SHALL also show when a lost game is loaded. While the game is over, the build rail and its drawers SHALL be disabled, only the inspect tool SHALL arm, taps and drags MUST NOT place or demolish, long-press SHALL NOT open the tile menu, and the research button SHALL be disabled with choosing research issuing no command. When the game ends, any armed tool, pending placement and tile menu request SHALL be cleared.

#### Scenario: Bankruptcy banner stays up

- **WHEN** the game is over and 100 more ticks pass
- **THEN** the session's banner is titled "Bankrupt" and names the pause menu and the title screen

#### Scenario: Build tools stay off after game over

- **WHEN** the game is over and the player arms the road, then taps a free tile
- **THEN** the inspect tool stays armed and no command is queued

#### Scenario: Game over disarms the armed tool

- **WHEN** the sawmill tool is armed and a tick emits `gameOver`
- **THEN** the inspect tool is armed and no placement is pending

#### Scenario: Research is off after game over

- **WHEN** the game is over and the player chooses an available tech
- **THEN** research is reported unavailable and no command is queued
