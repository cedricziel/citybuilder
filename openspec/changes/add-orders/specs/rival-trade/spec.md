## ADDED Requirements

### Requirement: Favour improves a rival's prices

The player's favour with a rival SHALL improve the prices at that rival's port by the favour's step: 5% at step 1 and 10% at step 2. The rival SHALL sell for the base-price rule's amount less that percent and SHALL buy for it plus that percent, each rounded down and at least $1. Standing offers and trades SHALL use the improved prices.

#### Scenario: Favour step 1 improves prices

- **WHEN** the player's favour with a rival is 6 and the prices of tools are read
- **THEN** the rival sells at $35 and buys at $23

#### Scenario: Favour step 2 improves prices

- **WHEN** the player's favour with a rival is 12 and the prices of tools are read
- **THEN** the rival sells at $33 and buys at $24

#### Scenario: Favour with one rival does not change another's prices

- **WHEN** the favour with rival 1 is 12 and the prices at rival 2's port are read
- **THEN** they are the base-price rule's amounts

## MODIFIED Requirements

### Requirement: Trading at a rival port

At a rival port, a player-owned ship's `loadUpTo` SHALL buy and `unloadUpTo` SHALL sell. A purchase SHALL move the least of the requested quantity, the ship's free space, the sell offer and what the player's balance pays for; the units SHALL leave the rival's island buffers in ascending entity ID order and the player SHALL pay the rival units × sell price. A sale SHALL move the least of the requested quantity, the ship's cargo of the good, the buy offer, what the rival's treasury pays for and the free space in the rival's buffers; the units SHALL go to the rival's town center, then its warehouses in ascending ID, then its port, and the rival SHALL pay the player units × buy price. While the player has an accepted order from that rival for the good, the buy offer for it SHALL be the larger of the standing offer and the order's remaining units, and the units sold SHALL count toward the order (`orders` / Rival orders are delivered by ship). Each action that moves at least one unit SHALL emit `tradeCompleted` with the rival, good, quantity, total and direction. No trade SHALL move anything after the player's game is over.

#### Scenario: Buying wood

- **WHEN** a player ship with 100 free capacity docks at rival 1's port with "load up to 20 wood", rival 1 sells 12 wood and the player has $1,000
- **THEN** the ship gains 12 wood, the player's balance drops by $60, rival 1's treasury rises by $60, and the tick emits `tradeCompleted(rival 1, wood, 12, 60, bought)`

#### Scenario: Selling tools

- **WHEN** a player ship carrying 30 tools docks at rival 1's port with "unload up to 30 tools", rival 1 holds no tools, has $1,000 and its town center has 25 free space
- **THEN** 20 tools go to rival 1's town center, the player's balance rises by $440 and rival 1's treasury drops by $440

#### Scenario: Rival can't pay

- **WHEN** a player ship unloads tools at a rival port whose treasury is $30
- **THEN** 1 tool is sold for $22

#### Scenario: Nothing to buy waits

- **WHEN** a player ship docks at a rival port with "load up to 10 iron" and the rival sells no iron
- **THEN** nothing moves, no `tradeCompleted` is emitted and the ship waits under the dock timeout

#### Scenario: A rival buys above its target for an accepted order

- **WHEN** the player has accepted rival 1's order for 30 planks, rival 1 holds 18 planks, and a player ship carrying 30 planks unloads at its port
- **THEN** all 30 planks are sold at the buy price, the order has 30 delivered, and without the order only 2 would have been bought
