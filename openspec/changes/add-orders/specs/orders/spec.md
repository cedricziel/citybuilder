## ADDED Requirements

### Requirement: Order templates are game data

A game-data pack SHALL be able to define `Order` templates. A template SHALL have an ID, an issuer (`crown` or `rival`), a good, a title, a line of text of at most 100 characters, a window in seasons from 1 to 8, a size percent from 1 to 300, a minimum and a maximum quantity with the minimum at least 1 and not above the maximum, and a reward percent from 0 to 500. It MAY name a first age, a favour gain and a favour loss, which default to the first age, 2 and 2. An Age item MAY define `orderEvery`, the seasons between crown orders, which defaults to 4. Loading SHALL reject a template that names an unknown good or age, or breaks a bound, and SHALL name the template.

The built-in pack SHALL define six crown templates (wood, planks, food, bread, iron, tools) and five rival templates (wood, planks, food, bread, tools), and `orderEvery` of 4 for Antiquity, 4 for the Middle Ages, 3 for the Renaissance and 2 for the Industrial age.

#### Scenario: Built-in order templates load

- **WHEN** the game data loads
- **THEN** it holds 6 crown and 5 rival order templates, and the ages' `orderEvery` are 4, 4, 3 and 2

#### Scenario: Unknown good in an order template is rejected

- **WHEN** a pack has an order template for the good silk and no good named silk exists
- **THEN** loading the pack fails and names the template

#### Scenario: Order template bounds are enforced

- **WHEN** a pack has an order template with a window of 0 seasons, or a minimum above its maximum, or a text of 101 characters
- **THEN** loading the pack fails and names the template

#### Scenario: Unknown age in an order template is rejected

- **WHEN** a pack has an order template whose first age is `stone`
- **THEN** loading the pack fails and names the template

### Requirement: The crown issues orders on a schedule

Orders SHALL be issued at season boundaries (every 600 ticks) in games with an active calendar, and never after the game is over. The crown SHALL issue its first order at season 4, the start of the second year, and then every `n` seasons, where `n` is the player's age's `orderEvery` times the difficulty's cadence percent (Easy 150, Normal 100, Hard 75) over 100, rounded to the nearest whole number and at least 1. It SHALL choose among the crown templates that are eligible (see "Order size follows the town's output") and whose first age the player has reached; it SHALL NOT choose the good of its previous order when another template is eligible; and it SHALL choose with a generator derived from the world's seed and the order number, never the world's own. The crown SHALL issue nothing when the board already holds 3 offers or no template is eligible.

#### Scenario: The crown's first order comes in year 2

- **WHEN** a Normal Medieval game whose town makes planks runs to tick 2,399 and then to tick 2,400
- **THEN** it has no order at tick 2,399 and one crown offer at tick 2,400

#### Scenario: The crown's cadence follows the age

- **WHEN** a Normal Renaissance game is run to season 10
- **THEN** the crown issued orders at seasons 4, 7 and 10

#### Scenario: Difficulty scales the cadence

- **WHEN** a Medieval game is run to season 10 on Hard, and another on Easy
- **THEN** the Hard game's crown issued orders at seasons 4, 7 and 10 and the Easy game's at seasons 4 and 10

#### Scenario: No order is issued when the town makes nothing

- **WHEN** a town that has made no goods reaches season 4
- **THEN** no order is issued

#### Scenario: A full board skips an issue

- **WHEN** the board holds 3 offers at a crown slot
- **THEN** the crown issues nothing at that slot

#### Scenario: A game without a calendar has no orders

- **WHEN** a world whose calendar is inactive runs 10,000 ticks
- **THEN** it holds no orders and `orders` equals an empty state

#### Scenario: No orders after the game is over

- **WHEN** the game is over and a season boundary passes
- **THEN** no order is issued and no shipment advances

#### Scenario: The crown varies its goods

- **WHEN** the crown's previous order was for planks and another crown template is eligible
- **THEN** the next crown order is not for planks

### Requirement: Rivals issue orders for goods they are short of

At a season boundary from season 4, each rival whose ID plus the season number is even SHALL issue an order if it has no order open (offered or accepted) and some rival template, whose first age the player has reached, names a good the rival is short of by the rule of its standing offers (it buys that good: its stock is below 20) and is eligible. The rival's treasury SHALL pay for the whole quantity at its buy price. The order's issuer is the rival.

#### Scenario: A short rival posts an order

- **WHEN** rival 2 holds 6 planks and $1,000 at season 6, and the player's town makes planks
- **THEN** rival 2 issues an order for planks

#### Scenario: A rival with no shortage posts nothing

- **WHEN** a rival holds 20 or more of every good it buys
- **THEN** it issues no order

#### Scenario: A rival has one open order at a time

- **WHEN** a rival's earlier order is still offered or accepted at its next slot
- **THEN** it issues no new order

#### Scenario: A rival that cannot pay posts nothing

- **WHEN** a short rival's treasury is below the quantity times its buy price
- **THEN** it issues no order for that good

### Requirement: Order size follows the town's output

For a template, the recent output SHALL be the units of its good that the player's producers made over the last up to 4 closed seasons, and the template is eligible only when at least one season is closed and the output is above zero. The quantity SHALL be `recent × seasons × size / (closed × 100)`, rounded down, where `seasons` and `size` are the template's, then times the difficulty's size percent (Easy 80, Normal 100, Hard 120) over 100 rounded down, then at most the template's maximum and at most 75% of what the player's stores road-connected to a town center can hold of the good (the sum of those stores' capacities for it), rounded down. A template whose quantity is below its minimum SHALL NOT be eligible.

The deadline SHALL be the end of the season that is `window` seasons after the issue, where `window` is the template's seasons times the difficulty's window percent (Easy 130, Normal 100, Hard 85) over 100, rounded to the nearest whole season and at least 1. The reward SHALL be `quantity × base price × reward percent / 100`, rounded down.

#### Scenario: Size follows recent output

- **WHEN** a Normal town made 120 planks over its last 4 seasons, and the crown's timber template (2 seasons, size 90, minimum 12, maximum 80, reward 125) is issued
- **THEN** the order asks for 54 planks, and its reward is $540

#### Scenario: Size is capped by the stores

- **WHEN** the same town's stores hold at most 60 planks together
- **THEN** the order asks for 45 planks

#### Scenario: Size is capped by the template

- **WHEN** a town made 400 planks over its last 4 seasons
- **THEN** the timber order asks for 80 planks

#### Scenario: Difficulty scales the size and the time

- **WHEN** the same orders are issued on Hard and on Easy
- **THEN** the Hard order asks for 64 planks and has a 2-season window (2 × 85%, rounded), and the Easy order asks for 43 planks and has a 3-season window (2 × 130%, rounded)

#### Scenario: Too little output is not asked for

- **WHEN** a town made 10 planks over its last 4 seasons
- **THEN** the timber template is not eligible

### Requirement: The board holds offers that lapse

An issued order SHALL be an offer on the board. An offer not accepted by the end of the season it was issued in SHALL lapse and leave the board without any effect on favour, and emit an expiry event. The board SHALL hold at most 3 offers.

#### Scenario: An offer lapses at the end of its season

- **WHEN** an offer issued at tick 2,400 is not accepted and the tick reaches 3,000
- **THEN** the order is expired, the board holds no offers, and favour is unchanged

#### Scenario: The board holds three offers

- **WHEN** three offers are open and a fourth would be issued
- **THEN** the fourth is not issued

### Requirement: The player accepts, declines and abandons orders

`acceptOrder` SHALL turn an offer into an accepted order, if the offer is still open and fewer than 2 orders are accepted. `declineOrder` SHALL remove an offer from the board without effect on favour. `abandonOrder` SHALL fail an accepted order that has nothing sent or delivered yet, with the favour penalty. A command naming an unknown or closed order, or breaking those conditions, SHALL be dropped without effect.

#### Scenario: Accepting an offer

- **WHEN** the player accepts an open offer
- **THEN** the order is accepted at the next tick and an acceptance event is emitted

#### Scenario: At most two orders are accepted

- **WHEN** two orders are accepted and the player accepts a third
- **THEN** the third stays an offer

#### Scenario: Declining an offer

- **WHEN** the player declines an offer
- **THEN** it leaves the board and favour is unchanged

#### Scenario: Abandoning an accepted order costs favour

- **WHEN** the player abandons an accepted crown order with nothing sent
- **THEN** the order fails, the crown's favour drops by the order's penalty, and the player's balance is unchanged

#### Scenario: Commands on closed orders do nothing

- **WHEN** the player accepts an expired order, abandons an unknown order, or dispatches an order that was declined
- **THEN** the world is unchanged

### Requirement: Crown orders are delivered by shipments from the stores

`dispatchOrder` on an accepted crown order with nothing sent SHALL send the whole quantity from the player's operational stores that hold the good and are road-connected to a player town center. Stores SHALL be taken nearest first (by path length to a town center, then by entity ID), each as much as it holds and the order still needs. The units SHALL leave the stores at once. A store that is a town center SHALL deliver at once. Every other store's units SHALL travel as one shipment along the roads to the nearest town center, advancing one tile a tick, and SHALL count toward the order when they arrive. The command SHALL do nothing when the stores hold fewer units than the quantity, when a leg has no road path, or when the longest leg's path length in tiles would pass the deadline.

`orderDispatchPlan(for:)` SHALL report the same plan, or why there is none, without changing the world, for the UI.

#### Scenario: Dispatch sends the goods from the stores

- **WHEN** an accepted order for 30 planks is dispatched and a warehouse holds 20 planks and the town center 15
- **THEN** the town center's 15 count at once, 15 planks leave the warehouse as one shipment, the warehouse holds 5, and the order has 15 delivered and 15 on the road

#### Scenario: Dispatch is refused when the stores hold too little

- **WHEN** an accepted order for 30 planks is dispatched while the stores hold 29
- **THEN** nothing leaves the stores and the order has nothing sent

#### Scenario: Dispatch is refused when it would arrive late

- **WHEN** a shipment's path is 40 tiles long and the deadline is 39 ticks away
- **THEN** the dispatch is refused and the stores keep their goods

#### Scenario: Goods in the town center count at once

- **WHEN** the town center holds all of the order's quantity and the order is dispatched
- **THEN** the order is fulfilled in that tick

#### Scenario: Shipments walk the road and arrive

- **WHEN** a shipment's path is 6 tiles long
- **THEN** the snapshot lists it among the carriers, its position advances one tile a tick, and its units count toward the order on arrival

#### Scenario: A rival's order cannot be dispatched

- **WHEN** the player dispatches an accepted rival order
- **THEN** the world is unchanged

#### Scenario: Dispatch frees room for a stopped producer

- **WHEN** a sawmill is stopped because every store holds 80 planks and an order for 40 planks is dispatched
- **THEN** the stores have room for planks again and the sawmill resumes

### Requirement: Rival orders are delivered by ship

An accepted order from a rival SHALL count the units of its good that a player ship sells to that rival at its port (`rival-trade` / Trading at a rival port) from the tick it was accepted, up to the order's remaining units. The dispatch command SHALL NOT apply to it.

#### Scenario: Units sold at the rival's port count

- **WHEN** a player ship unloads 12 planks at rival 1's port while the player has accepted rival 1's order for 30 planks
- **THEN** the order has 12 delivered, and the ordinary trade is paid at the port

#### Scenario: Units sold before accepting do not count

- **WHEN** a player ship unloads 12 planks at the port and the player accepts the rival's order afterwards
- **THEN** the order has nothing delivered

### Requirement: Fulfilling an order pays money and favour

When an accepted order's delivered units reach its quantity, in the tick they do, the order SHALL be fulfilled: the player's balance SHALL rise by its reward, the issuer's favour by its gain, the fulfilled count by one, and a fulfilment event SHALL be emitted once. An order fulfilled at its deadline tick SHALL count as on time.

#### Scenario: Fulfilling a crown order

- **WHEN** a shipment completes an order for 54 planks with a reward of $540 and a favour gain of 2
- **THEN** the balance rises by $540, the crown's favour by 2, the fulfilled count by 1, and `orderFulfilled` is emitted once

#### Scenario: Fulfilling a rival order

- **WHEN** a ship's unloading completes a rival order with a reward of $120
- **THEN** the balance rises by $120 on top of the trade's pay, and the rival's favour by the gain

#### Scenario: Fulfilling at the deadline tick is on time

- **WHEN** a shipment arrives in the tick that is the order's deadline
- **THEN** the order is fulfilled and not failed

### Requirement: Missing a deadline costs favour, never money

An accepted order not fulfilled by the tick after its deadline SHALL fail: the issuer's favour SHALL fall by the order's penalty, a failure event SHALL be emitted once, and the player's balance and stores SHALL be unchanged. Favour SHALL stay between −10 and 20.

#### Scenario: A missed deadline costs favour

- **WHEN** an accepted order is not fulfilled by the tick after its deadline
- **THEN** the order fails, the issuer's favour drops by the penalty, and the balance and stores are unchanged

#### Scenario: Favour is clamped

- **WHEN** an issuer's favour is −9 and another failure costs 3, or is 19 and a fulfilment gains 2
- **THEN** the favour is −10 and 20

### Requirement: Favour has steps

Favour SHALL be a whole number per issuer: the crown and each rival. Its step SHALL be 0 below 6, 1 from 6 and 2 from 12. The steps SHALL be listed on the board's readout, with the perk each gives (see `research` and `rival-trade`).

#### Scenario: Favour steps

- **WHEN** favour is 5, 6, 11, 12
- **THEN** the steps are 0, 1, 1, 2

### Requirement: An ignored order changes nothing else

Orders SHALL run in their own step and SHALL NOT draw from the world's random generator. A game whose player ignores every order SHALL play exactly as it would without orders, apart from the orders' own state. Two worlds started alike and given the same commands SHALL stay equal.

#### Scenario: Ignored orders do not change the town

- **WHEN** two Normal games with an active calendar run 5,000 ticks with the same commands, and orders are cleared from one after every tick
- **THEN** every other part of the two worlds is equal

#### Scenario: Orders are deterministic

- **WHEN** two worlds are started alike and given the same commands including accepting and dispatching orders
- **THEN** they are equal after every tick

### Requirement: Orders and per-good storage

An order SHALL ask for no more of a good than 75% of what the player's connected stores can hold of it. A shipment SHALL take its units out of the stores and so free their room. Goods inside producers, on the road and on ships SHALL NOT count as stored.

#### Scenario: Goods on the road are not stored

- **WHEN** a producer holds 12 planks in its own stockpile and a carrier walks 3 more
- **THEN** a dispatch counts none of them
