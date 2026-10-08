## ADDED Requirements

### Requirement: Rivals build a port

A rival with no port and at least 6 houses SHALL, before its script step, place a port at the first anchor in a square spiral around its town center anchor (out to radius 40) where the port can be placed for that rival, when its treasury is at least $300 and its island stock holds 8 wood and 6 planks. The port SHALL NOT need a road. The rule SHALL NOT advance the script. After 10 turns waiting on it, the rule SHALL be suspended for 100 turns.

#### Scenario: Rival places its port

- **WHEN** a rival with 6 houses, no port, $500, 10 wood, 8 planks and 20 food takes a turn
- **THEN** its commands are a single port placement on a shore of its island and its script index is unchanged

#### Scenario: Too small for a port

- **WHEN** a rival with 5 houses and no port takes a turn
- **THEN** it does not place a port

### Requirement: Base prices

Every good SHALL have a base price: wood 4, planks 8, food 4, bread 12, grain 3, flour 6, ore 5, charcoal 5, iron 14, tools 30. A rival SHALL sell a good at 125% and buy it at 75% of its base price, rounded down and at least $1.

#### Scenario: Tool prices

- **WHEN** the rival prices of tools are read
- **THEN** the sell price is $37 and the buy price is $22

#### Scenario: Grain buy price floor

- **WHEN** the rival buy price of grain is read
- **THEN** it is $2

#### Scenario: Every good is priced

- **WHEN** the base price of every good in the catalog is read
- **THEN** each is at least $1

### Requirement: Rival offers

A rival SHALL offer to sell every good its island stock holds more than 30 of, in the amount above 30, and SHALL offer to buy wood, planks, food, bread and tools up to 20 in stock. Offers SHALL be derived from the current island stock and listed in catalog order.

#### Scenario: Surplus for sale

- **WHEN** a rival's island holds 42 wood and 12 planks
- **THEN** it sells 12 wood and buys 8 planks

#### Scenario: Never both

- **WHEN** a rival's island holds 25 food
- **THEN** it neither sells nor buys food

### Requirement: Trading at a rival port

At a rival port, a player-owned ship's `loadUpTo` SHALL buy and `unloadUpTo` SHALL sell. A purchase SHALL move the least of the requested quantity, the ship's free space, the sell offer and what the player's balance pays for; the units SHALL leave the rival's island buffers in ascending entity ID order and the player SHALL pay the rival units × sell price. A sale SHALL move the least of the requested quantity, the ship's cargo of the good, the buy offer, what the rival's treasury pays for and the free space in the rival's buffers; the units SHALL go to the rival's town center, then its warehouses in ascending ID, then its port, and the rival SHALL pay the player units × buy price. Each action that moves at least one unit SHALL emit `tradeCompleted` with the rival, good, quantity, total and direction. No trade SHALL move anything after the player's game is over.

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
