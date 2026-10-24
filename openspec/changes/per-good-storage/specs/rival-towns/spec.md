## MODIFIED Requirements

### Requirement: Rival build order

A rival SHALL build only houses, roads, lumberjack huts, foresters, sawmills, farms and warehouses. On its turn it SHALL take the first threshold rule that applies and that it can carry out, otherwise the next script step.

Before the threshold rules, a rival whose town center has room for fewer than 4 food, so the farms' next harvest has nowhere to go, with no warehouse built or under construction and no site waiting for materials, SHALL build a warehouse if it can carry the step out. It SHALL take this step at the building cap too.

The threshold rules, in order:

- food below 4 and farms × 2 < houses × 3 → farm;
- no operational or constructing sawmill, at least one lumberjack hut and fewer than 4 planks in stock → sawmill;
- once the opening is complete, planks below 6 with fewer sawmills than lumberjack huts → sawmill;
- wood below 4 with fewer than 1 + houses / 4 lumberjack huts, or less than 6 forest tiles left in the rival's hut catchments → lumberjack hut, unless the rival has a forester and already at least 2 + houses / 2 lumberjack huts, counting every hut;
- once the opening is complete and the rival has at least 4 houses, fewer foresters than lumberjack huts, counting every hut → forester.

Huts with fewer than 4 forest tiles left in their catchment SHALL not count as huts in these rules.

The script SHALL be the opening (lumberjack hut, sawmill, farm, house, lumberjack hut, house, house, farm, house, house, lumberjack hut, warehouse), played once, then the growth loop (house, house, farm, house, house, lumberjack hut, house, sawmill), repeated. Stock SHALL be the rival's island stock.

A step SHALL be issued only when:

- the treasury covers the building cost, the road cost and $50, plus a $150 reserve while the rival has fewer than 3 houses with residents, unless the step is a house, a farm, or a sawmill while the rival has none and fewer planks in stock than a house needs; and
- the island stock covers the material cost, or the rival's own huts (and, for planks, its sawmill) can still deliver the rest.

Otherwise the rival waits. While one of its sites waits for materials, a rival SHALL take no script step and only a lumberjack hut may join the waiting site. A rival's lumberjack hut, forester and first sawmill SHALL cost no materials. A script step waited on for 10 turns SHALL be skipped.

House steps SHALL be skipped at the house cap: 16 houses on Easy, 24 on Normal, 32 on Hard. Lumberjack hut steps SHALL be skipped while the rival has a forester and at least 2 + houses / 2 lumberjack huts, counting every hut. Warehouse steps SHALL be skipped once the rival has a warehouse built or under construction. No other step SHALL be taken at the building cap: 32 buildings on Easy, 48 on Normal, 64 on Hard, counting every rival building except roads and foresters.

#### Scenario: Opening step

- **WHEN** a fresh rival takes its first turn with 6 wood, 5 planks and 2 food
- **THEN** its commands end with a lumberjack hut placement and its script index becomes 1, although food is below 4 and there are no houses to feed

#### Scenario: Food threshold overrides the script

- **WHEN** a rival past its opening with 4 houses, 1 farm and 3 food in stock takes a turn while its script points at a house
- **THEN** it places a farm and its script index is unchanged

#### Scenario: Fewer farms than houses

- **WHEN** a rival past its opening with 5 houses, 4 farms and 2 food in stock takes a turn while its script points at a house
- **THEN** it places a farm

#### Scenario: Three farms for every two houses

- **WHEN** a rival past its opening with 4 houses, 5 farms and 2 food in stock takes a turn while its script points at a house
- **THEN** it places a farm, while with 6 farms it does not

#### Scenario: Waiting for money

- **WHEN** a rival with $40 takes a turn on a house step
- **THEN** it issues no commands and its wait count goes up by 1

#### Scenario: Reserve keeps money for the first houses

- **WHEN** a rival with 1 house with residents and $230 takes a turn on a lumberjack hut step whose slot needs no new roads
- **THEN** it issues no commands, because $80 + $50 + the $150 reserve exceeds its treasury

#### Scenario: Houses and the first sawmill ignore the reserve

- **WHEN** a rival with no houses, no sawmill, 3 planks, the sawmill's wood and $175 takes a turn on a sawmill step whose slot needs no new roads
- **THEN** it places the sawmill, while with 5 planks, enough for a house, it waits

#### Scenario: Sawmill before planks run out

- **WHEN** a rival with a lumberjack hut, no sawmill, 3 planks, 10 wood and enough money takes a turn while its script points at a house
- **THEN** it places a sawmill and its script index is unchanged

#### Scenario: A rival's first sawmill costs no materials

- **WHEN** the material cost of a sawmill is read for a rival without a sawmill, for the player, and for a rival that has one
- **THEN** the first is empty, and the other two are the catalog's wood and planks

#### Scenario: Skipping a stuck step

- **WHEN** a rival has waited 10 turns on the same script step
- **THEN** its script index advances past that step and its wait count resets to 0

#### Scenario: House cap

- **WHEN** a Normal rival with 24 houses reaches a house step
- **THEN** it skips the step and takes the next one

#### Scenario: Replanting towns keep their huts

- **WHEN** a rival past its opening with 4 houses, a forester, 2 wood and 4 lumberjack huts whose forest is cut takes a turn
- **THEN** it does not place a lumberjack hut, while without the forester it does

#### Scenario: A full town center gets a warehouse

- **WHEN** a rival past its opening with no warehouse, a town center holding 38 food and enough money takes a turn
- **THEN** it places a warehouse, while with 30 food it does not

#### Scenario: The building cap does not stop a first warehouse

- **WHEN** a Normal rival at the building cap, with no warehouse, a town center holding 38 food and enough money takes a turn
- **THEN** it places a warehouse, while a rival that already has a warehouse issues no commands

#### Scenario: Script hut steps stop at the hut limit

- **WHEN** a rival with 8 houses, 6 foresters and 6 lumberjack huts takes a turn while its script points at a lumberjack hut
- **THEN** it skips the step and places the house that follows, while with 5 huts it places the hut

#### Scenario: One warehouse per town

- **WHEN** a rival that already has a warehouse takes a turn while its script points at the opening's warehouse
- **THEN** it skips the step and places the house that follows

#### Scenario: Building cap ignores foresters and roads

- **WHEN** a Normal rival with 40 buildings other than roads and foresters, plus 8 foresters, takes a turn on a farm step
- **THEN** it places the farm

#### Scenario: Rival replants beside its hut

- **WHEN** a rival past its opening with 4 houses, 2 lumberjack huts, 1 forester, and enough food, planks and wood takes a turn while its script points at a house
- **THEN** it places a forester and its script index is unchanged

#### Scenario: Foresters wait for the town

- **WHEN** a rival still in its opening, with 2 lumberjack huts and no forester, takes a turn
- **THEN** it does not place a forester

#### Scenario: Rival forester needs open ground beside a hut

- **WHEN** a rival with 4 houses and 1 lumberjack hut, past its opening and with no forester, takes a turn, and no free slot's catchment shares at least 4 open grass tiles with the hut's catchment
- **THEN** it does not place a forester and takes its next script step instead

## ADDED Requirements

### Requirement: Rival market trades per good

A rival SHALL trade at its own town center's market in four cases.

1. **Unblock.** When a step it takes (a threshold rule or a script step) lacks only wood or planks that its own huts and sawmill cannot supply, and the treasury covers the purchase, the step and $50, the rival SHALL buy the shortfall in the same batch, ahead of the step's roads and building, so no carrier takes the goods first. A step that its huts or sawmill can still supply SHALL be placed without a purchase and SHALL wait for their delivery, because the market charges 150%. A rival at the building cap, or on a house step at the house cap, takes no step and so buys nothing for one.
2. **Pay debts.** On its turn, before the threshold rules, while the treasury is below $150, the rival SHALL sell every unit above 12 of planks, then wood, then food, one good per turn. The trade takes the turn.
3. **Sell surplus.** On its turn, before the threshold rules, for planks, then wood, while its goods buffers together have room for fewer than 20 more of that good, the rival SHALL sell every unit of it above 60, one good per turn. The trade takes the turn.
4. **Feed.** On its turn, before the threshold rules, while food is below 4, one of the rival's houses is short of food and the treasury is at least $300, the rival SHALL buy up to 5 food. The trade takes the turn.

Rival trades SHALL use the player's market prices. They SHALL count against seasonal limits kept per rival, which reset when the season changes and persist in saves. They SHALL be applied at the next tick boundary through the command queue. Bought goods SHALL go into the rival's town center, and sold goods SHALL come from the rival's goods buffers. The units a sale keeps or sells SHALL be counted in the rival's own operational goods buffers, not in the player's stores on the same island. A rival SHALL NOT buy more of a good than its town center has room for, so a town center full of that good never costs it its turn. A rival trade SHALL NOT change the player's balance, stock or market counts, and SHALL NOT emit `marketTraded`.

#### Scenario: Rival buys the planks it is missing

- **WHEN** a rival with no lumberjack hut, no sawmill, no planks and $400 takes a turn whose house step waits only for 4 planks
- **THEN** its commands buy 4 planks at the market price and then place the house, and when they apply the house does not wait for materials

#### Scenario: Rival in debt sells surplus planks

- **WHEN** a rival with −$20 and 40 planks takes a turn
- **THEN** it sells 20 planks, the seasonal limit, and its treasury rises by 20 × the market's plank sell price

#### Scenario: Rival sells surplus planks from crowded stores

- **WHEN** a rival with $5,000, 10 food and 101 planks, whose town center and warehouse together have room for 19 more planks, takes a turn
- **THEN** it sells 20 planks, the seasonal limit, while with 100 planks and room for 20 it sells none

#### Scenario: Rival sales count only its own stores

- **WHEN** a rival with $5,000 and 75 of its own planks, and a full player warehouse on its island holding 80 planks, takes a turn
- **THEN** it sells no planks, since only its own stores count

#### Scenario: Rival buys food for short houses

- **WHEN** a rival with $500, 1 food and a house short of food takes a turn
- **THEN** it buys 5 food

#### Scenario: No purchase for a step the caps rule out

- **WHEN** a rival at the building cap, with no planks and $400, takes a turn whose house step waits only for planks
- **THEN** it buys no planks

#### Scenario: Rival limits are its own

- **WHEN** a rival has bought 10 food this season and the player buys food
- **THEN** the player's purchase is filled up to the player's own limit and the rival can buy no more food until the season changes

#### Scenario: Rival trades leave the player alone

- **WHEN** a rival sells planks at its market
- **THEN** the player's balance, stock and market counts are unchanged and no `marketTraded` event is emitted

## REMOVED Requirements

### Requirement: Rival market trades
**Reason**: With stores that hold each good separately, a town center can no longer be full and short of food at once, and a food purchase can no longer be blocked by other goods, so "Rival clears a full town center" and "No purchase into a full town center" cannot happen. Crowding is measured per good.
**Migration**: "Rival market trades per good" keeps the unblock, debt, surplus and feed trades; the debt sale no longer has a full-store trigger, surplus sales look at the room for each good, and purchases are limited by the town center's room for the good bought.
