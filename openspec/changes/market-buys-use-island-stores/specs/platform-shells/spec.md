## MODIFIED Requirements

### Requirement: Town center market panel

Selecting a player town center SHALL show a market section in the inspector's details. It SHALL list, in catalog order, every good with a non-zero limit as "Wood — buy $6 (10 left) · sell $2 (20 left)", leaving out a side whose limit is 0. Each row SHALL offer Buy 1, Buy 5, Sell 1 and Sell 5, each enqueueing the matching market command for that town center. A Buy button SHALL be disabled when nothing is left to buy, every goods buffer on the town center's island is full, or the balance is below the price. A Sell button SHALL be disabled when nothing is left to sell or the island holds none of the good. Every button SHALL be disabled after the game is over. A rival's town center SHALL show no market.

#### Scenario: Town market rows
- **WHEN** the player selects their town center at the start of a season with $1,000
- **THEN** the market's first row reads "Wood — buy $6 (10 left) · sell $2 (20 left)" and the tools row reads "Tools — sell $15 (20 left)"

#### Scenario: Buy button enqueues a market command
- **WHEN** the player taps Buy 5 on the wood row of their town center
- **THEN** a `marketBuy` command for that town center, wood and 5 is enqueued

#### Scenario: Buy disabled at the limit
- **WHEN** the player has bought 10 wood this season
- **THEN** both wood Buy buttons are disabled

#### Scenario: Buy enabled while a warehouse has room
- **WHEN** the player's town center is full and a warehouse on its island has room
- **THEN** the wood Buy buttons are enabled

#### Scenario: Sell disabled without stock
- **WHEN** the player's island holds no iron
- **THEN** both iron Sell buttons are disabled

#### Scenario: Market locked after game over
- **WHEN** the game is over and the player selects their town center
- **THEN** every market button is disabled

#### Scenario: No market at a rival town center
- **WHEN** the player selects a rival's town center
- **THEN** the inspector shows no market section
