## MODIFIED Requirements

### Requirement: Rival market trades

A rival SHALL trade at its own town center's market in four cases.

1. **Unblock.** When a step it takes (a threshold rule or a script step) lacks only wood or planks that its own huts and sawmill cannot supply, and the treasury covers the purchase, the step and $50, the rival SHALL buy the shortfall in the same batch, ahead of the step's roads and building, so no carrier takes the goods first. A step that its huts or sawmill can still supply SHALL be placed without a purchase and SHALL wait for their delivery, because the market charges 150%. A rival at the building cap, or on a house step at the house cap, takes no step and so buys nothing for one.
2. **Pay debts or clear the store.** On its turn, before the threshold rules, while the treasury is below $150, or its town center has fewer than 4 units of room and food is below 4, the rival SHALL sell every unit above 12 of planks, then wood, then food, one good per turn. The trade takes the turn.
3. **Sell surplus.** On its turn, before the threshold rules, while its goods buffers together have fewer than 40 units of room, the rival SHALL sell every unit above 60 of planks, then wood, one good per turn. The trade takes the turn.
4. **Feed.** On its turn, before the threshold rules, while food is below 4, one of the rival's houses is short of food and the treasury is at least $300, the rival SHALL buy up to 5 food. The trade takes the turn.

Rival trades SHALL use the player's market prices. They SHALL count against seasonal limits kept per rival, which reset when the season changes and persist in saves. They SHALL be applied at the next tick boundary through the command queue. Bought goods SHALL go into the rival's town center, and sold goods SHALL come from the rival's goods buffers. The units a sale keeps or sells SHALL be counted in the rival's own operational goods buffers, not in the player's stores on the same island. A rival SHALL NOT buy more than its town center has room for, so a full town center never costs it its turn. A rival trade SHALL NOT change the player's balance, stock or market counts, and SHALL NOT emit `marketTraded`.

#### Scenario: Rival buys the planks it is missing

- **WHEN** a rival with no lumberjack hut, no sawmill, no planks and $400 takes a turn whose house step waits only for 4 planks
- **THEN** its commands buy 4 planks at the market price and then place the house, and when they apply the house does not wait for materials

#### Scenario: Rival in debt sells surplus planks

- **WHEN** a rival with −$20 and 40 planks takes a turn
- **THEN** it sells 20 planks, the seasonal limit, and its treasury rises by 20 × the market's plank sell price

#### Scenario: Rival clears a full town center

- **WHEN** a rival with $5,000 and a town center holding 38 planks and 2 food takes a turn
- **THEN** it sells 20 planks, the seasonal limit

#### Scenario: Rival sells surplus planks from crowded stores

- **WHEN** a rival with $5,000, 10 food and 90 planks, whose town center and warehouse together have 30 units of room, takes a turn
- **THEN** it sells 20 planks, the seasonal limit, while with 50 units of room it sells none

#### Scenario: Rival sales count only its own stores

- **WHEN** a rival with $5,000, crowded stores holding 70 of its own planks, and a player warehouse on its island holding 100 planks takes a turn
- **THEN** it sells 10 planks

#### Scenario: Rival buys food for short houses

- **WHEN** a rival with $500, 1 food and a house short of food takes a turn
- **THEN** it buys 5 food

#### Scenario: No purchase for a step the caps rule out

- **WHEN** a rival at the building cap, with no planks and $400, takes a turn whose house step waits only for planks
- **THEN** it buys no planks

#### Scenario: No purchase into a full town center

- **WHEN** a rival with $500, 1 food, a house short of food and a town center full of goods it keeps (12 wood, 12 planks, 15 iron) takes a turn
- **THEN** it buys no food and takes its build step instead

#### Scenario: Rival limits are its own

- **WHEN** a rival has bought 10 food this season and the player buys food
- **THEN** the player's purchase is filled up to the player's own limit and the rival can buy no more food until the season changes

#### Scenario: Rival trades leave the player alone

- **WHEN** a rival sells planks at its market
- **THEN** the player's balance, stock and market counts are unchanged and no `marketTraded` event is emitted
