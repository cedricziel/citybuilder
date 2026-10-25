## ADDED Requirements

### Requirement: The world keeps a bounded history of seasons

The world SHALL record, for the player, one record per finished season and one for the season in progress. A season is `CalendarState.ticksPerSeason` ticks, whether or not the calendar is active. The history SHALL keep at most 40 finished seasons, dropping the oldest first, and SHALL be part of the saved world. A record SHALL hold only integers, and a good, producer kind or house tier whose numbers are all zero SHALL be absent from it.

#### Scenario: A season closes at the boundary
- **WHEN** the world ticks to a multiple of 600
- **THEN** the history has one more finished season, numbered for the season that just ended, and the season in progress has recorded nothing

#### Scenario: The ring is bounded
- **WHEN** the world runs 45 seasons
- **THEN** the history holds 40 finished seasons, the oldest is season 5 and the newest is season 44

#### Scenario: Empty entries are left out
- **WHEN** a season passes in which no tools were made, used, sold or bought and none are stored
- **THEN** the season's record has no entry for tools

#### Scenario: The history is deterministic
- **WHEN** two worlds with the same seed and commands run the same ticks, one of them saved and loaded halfway through a season
- **THEN** their histories are equal at the end

### Requirement: Goods flows are recorded per good

For each good the season record SHALL hold the units made by the player's producers, used by houses, used by production (recipe inputs and fuel), used by construction, sold and bought, and the units in the player's goods buffers at season end. The season record SHALL also hold the player's store capacity (the capacity of its goods buffers, summed) and its age at season end. Selling and buying SHALL count the town market, rival ports and caravans.

#### Scenario: Made and used by production
- **WHEN** a sawmill completes a cycle that takes 1 wood and makes 1 planks
- **THEN** the season has 1 planks made and 1 wood used by production

#### Scenario: Houses count what they drew
- **WHEN** a house wants 4 bread and the buffers on its road network hold 3
- **THEN** the season has 3 bread used by houses

#### Scenario: Construction counts when the building completes
- **WHEN** a building that costs 4 planks completes
- **THEN** the season has 4 planks used by construction

#### Scenario: Trade
- **WHEN** the player sells 5 wood at the market and buys 2 food from a rival port
- **THEN** the season has 5 wood sold and 2 food bought

#### Scenario: Stock is read at the boundary
- **WHEN** a season closes with 80 bread in the player's stores, whose capacities sum to 200
- **THEN** the season's bread stock is 80 and its store capacity is 200

#### Scenario: The age is read at the boundary
- **WHEN** a season closes while the player is in the Renaissance
- **THEN** the season's age is the Renaissance

#### Scenario: Rivals' goods are not recorded
- **WHEN** a rival's sawmill completes a cycle
- **THEN** the season has no planks made

### Requirement: Money flows are recorded

The season record SHALL hold the tax collected, the upkeep paid, the money earned and the money spent in trade, and the balance at season end.

#### Scenario: Tax and upkeep
- **WHEN** a collection credits $12 of tax and a collection deducts $5 of upkeep in one season
- **THEN** the season has tax 12 and upkeep 5

#### Scenario: Trade money
- **WHEN** the player sells goods for $40 and buys goods for $15 in one season
- **THEN** the season has trade income 40 and trade spending 15

### Requirement: People are recorded per tier and per rival

The season record SHALL hold the residents of the player's houses per house tier at season end, and for each rival its residents, age and treasury.

#### Scenario: Residents per tier
- **WHEN** a season closes with 12 peasants and 5 citizens in the player's houses
- **THEN** the season has 12 residents at the peasants tier and 5 at the citizens tier

#### Scenario: Rivals
- **WHEN** a season closes in a world with a rival of 9 residents, a treasury of $700 and the Medieval age
- **THEN** the season has that rival with 9 residents, $700 and the Medieval age

### Requirement: Producer activity is sampled

Every 10 ticks the system SHALL classify each operational player producer as working, waiting for input, stopped with its output stuck, or blocked for another reason, and add one to that class for its kind. A producer SHALL count as stopped with its output stuck when its production is stalled, every recipe input is present and a cycle's output does not fit its stockpile. That sample SHALL also add one to the stuck count of the good the producer holds most of among its outputs, the first in catalog order on a tie.

#### Scenario: A working producer
- **WHEN** a farm with a free stockpile is sampled
- **THEN** the season has one working sample for farms

#### Scenario: Waiting for input
- **WHEN** a bakery with no flour is sampled
- **THEN** the season has one waiting sample for bakeries

#### Scenario: Output stuck
- **WHEN** a bakery whose stockpile cannot take another loaf, and which holds flour, is sampled
- **THEN** the season has one stuck sample for bakeries and one stuck sample for bread

#### Scenario: Blocked for another reason
- **WHEN** a lumberjack hut with no trees in reach is sampled
- **THEN** the season has one blocked sample for lumberjack huts

#### Scenario: Between samples nothing is recorded
- **WHEN** a producer is stuck for 9 ticks that contain no sampling tick
- **THEN** the season has no stuck sample

### Requirement: The Statistics sheet

The game SHALL offer a Statistics sheet from a HUD menu button on iPhone, iPad, Mac and Apple TV. The sheet SHALL be read-only and SHALL have a segmented control with Goods, Money, People and Rivals, and Rivals SHALL appear only when the world has rivals. The sheet SHALL read the snapshot's history and draw its finished seasons, oldest to newest, with the season in progress left out.

- **Goods** SHALL list the goods that have any number in the history, each with made and used per season and the net (made minus used) of the latest season. A good that has producers stopped now with its output stuck SHALL show how many, and the list SHALL say how many producers are stopped in all. Selecting a good SHALL show its made and used bars, its store level against the store cap (a dashed line at the latest season's store capacity), a strip of the share of the season its producers were stopped with its output stuck, and, per producer kind that makes it, the shares working, waiting, stuck and blocked in the latest season. On a compact width the list SHALL push the detail.
- **Money** SHALL show tax and trade income above the axis, upkeep below it and the balance line.
- **People** SHALL show residents per tier, stacked.
- **Rivals** SHALL show residents per town as lines, and each town's residents, age and wealth, all read from the latest finished season.

On Apple TV the good list SHALL take focus, the tabs SHALL be focusable above it, and Menu SHALL close the sheet.

#### Scenario: A stopped producer is shown
- **WHEN** 2 bakeries are stopped now with bread stuck, and the history has stuck samples for bread
- **THEN** the Goods list shows "2 stopped" on bread and "2 producers stopped: output stuck" above the list, and the bread detail shows the stuck strip

#### Scenario: Nothing stuck, nothing shown
- **WHEN** no producer is stopped now and the history has no stuck samples
- **THEN** the Goods list shows no stopped pill and no summary banner, and no good's detail shows the stuck strip

#### Scenario: The sheet opens on the good that needs a look
- **WHEN** the Goods tab opens
- **THEN** it selects a good with a producer stopped now, else the good that was busiest in the latest season

#### Scenario: Empty history
- **WHEN** the sheet opens before the first season has closed
- **THEN** it says no season has finished yet, and draws no chart

#### Scenario: Rivals tab is conditional
- **WHEN** the world has no rivals
- **THEN** the segmented control has Goods, Money and People only

#### Scenario: The sheet does not change the world
- **WHEN** the sheet opens, switches tabs and closes
- **THEN** no command is enqueued
