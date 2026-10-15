## ADDED Requirements

### Requirement: Game-over banner and tools

While the game is over, the game screen SHALL show a banner titled "Bankrupt" that says the treasury stayed in the red too long and that the player can still save from the pause menu, or quit to the title to load a save or start a new game. The banner MUST NOT expire and MUST take the place of any other banner. It SHALL also show when a lost game is loaded. While the game is over, the session MUST NOT queue any player command. The build rail and its drawers SHALL be disabled, only the inspect tool SHALL arm, taps and drags MUST NOT place or demolish, neither long-press nor the inspector's Actions button SHALL open the tile menu, and a tile menu choice SHALL do nothing. The research button SHALL be disabled. The inspector's Demolish, commission, export and Route-from-here controls and the route list's New Route and per-route actions SHALL be disabled, and route mode SHALL NOT start. When the game ends, any armed tool, pending placement, tile menu request and route mode SHALL be cleared.

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

#### Scenario: Tile menu stays shut after game over

- **WHEN** the game is over, a building is selected, and the player picks Road from a tile menu
- **THEN** the session offers no tile menu, the inspect tool stays armed and no command is queued

#### Scenario: Inspector and route actions are off after game over

- **WHEN** the game is over and the player demolishes the selected building, commissions art, picks an export, starts a route or pauses a route
- **THEN** no command is queued and route mode does not start

#### Scenario: Game over ends route mode

- **WHEN** route mode is open and a tick emits `gameOver`
- **THEN** route mode ends
