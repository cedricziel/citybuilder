## Context

The logistics today, from `World+Carriers.swift`, `World+Supply.swift` and `World+Population.swift`:

- **Producers:** every tick, each producer with fewer than 2 carriers out (`CarrierConfig.perProducerCap`) sends 1 unit of its first output in stock. It goes to the nearest waiting construction site that still needs the good, else to the nearest goods buffer with room. The goods buffers are the warehouse, the port and the town center.
- **Consumers:** a producer with inputs (or fuel) is a consumer. When its stock plus inbound units falls below twice the recipe amount, a supply carrier brings 1 unit from the nearest buffer holding the good.
- **Houses:** every 100 ticks, `World.consume` pulls food, planks, bread and tools out of buffers on the house's road network, lowest entity ID first. A need is met while any buffer on that network holds the good and the last consumption was not short.
- **Movement and order:**
  - Carriers step one road tile per tick (10 ticks per second at speed 1).
  - Producers, consumers and goods are visited in entity order, and ties go to the shorter path, then the lower entity ID.
  - Rivals run the same systems on their own islands.

## Goals / Non-Goals

**Goals**
- Every good a player sees produced is seen carried to where it is used.
- Houses are supplied by visible deliveries, not by a road-network query.
- Bulk and long hauls use carts, so a busy town reads as organised traffic.
- Deterministic, save-compatible, and no more expensive per tick than today at the sizes we ship.

**Non-Goals**
- Player-set routes or priorities.
- Carts larger than a road tile.
- New production chains.

## Decisions

### D1. Destination order for a producer's output (milestone 1)

For each unit a producer sends, it looks for a destination in this order:

1. **A waiting construction site** that still needs the good. This is unchanged.
2. **A short consumer**, unless the good is a construction material or a house need (see below). It must be operational, have the same owner, and share the producer's road network. Its recipe inputs or fuel include the good, and its stock plus inbound units is below twice the recipe amount. This is the same threshold `needsSupply` uses today. The nearest one by road path wins; ties go to the lower entity ID.
3. **The nearest goods buffer with room.** This is unchanged, except as D5 adds for milestone 2.

**Room.** A consumer counts as short only while its stockpile has free room for every unit already on the way plus one. That applies to supply carriers from storage too.

**New mission.** Deliveries in step 2 use a new mission case, `.deliverToConsumer(good:amount:fromProducer:toConsumer:)`. On arrival it deposits into the consumer's stockpile.

**No double supply.** `supplyCarrierCount(to:)` counts these deliveries as inbound, so a consumer fed directly does not also get a supply carrier for the same need.

**Storage goods skip step 2.** Construction materials (wood, planks, iron: any good a building costs) and goods a house tier of the owner's culture needs always go to storage. Building placement and house consumption draw on storage, and a workshop taking them at the source starves both.
- *Evidence:* the first M1 build sent every good to short consumers. Lumberjack wood went to sawmills and charcoal burners before storage. The mid-game pacing sweep lost its first merchant in 61 of 180 arms, and bankruptcies rose from 7 to 27 of 180. The guided first-hour sweep lost residents in 14 of 20 games. A probe of normal/single-island/careful seed 0 showed the town never building its bakery or a second sawmill, with wood in storage near 0 for two years.
- With storage goods excluded, the same probe reaches the Renaissance at 3.75 years as on main. What still hops is the intermediates: grain → windmill, flour → bakery, ore and charcoal → smelter, hops → brewery and the like. That is the chain the owner asked to see.

*Why:* this is the smallest rule that makes chains visible, and it reuses the existing shortage threshold, so consumers neither starve nor hoard.

*Rejected:* always delivering producer → consumer. Then output would pile up at the producer whenever nobody is short, and storage and the market would stop seeing intermediates.

### D1b. Carried goods are never lost

A carrier whose destination cannot take all it carries keeps the rest. That happens when the destination is full or was demolished while the carrier walked, and it holds for every mission.
- It goes on to the nearest goods buffer of its owner with room, by road from where it stands.
- With none, it goes back to where the goods came from.
- With neither, it waits where it stands and tries its destination again each tick.
- A producer's goods continue as a delivery to storage, so the producer's carrier slot frees on final arrival. A retrieval stays a retrieval.
- A construction delivery to a site that is gone or already built is handled the same way.
- Only when both ends of the trip are gone, so no owner is known, is the unit dropped.

### D2. Distances without a search per pair (milestone 1)

A short consumer is chosen by road distance.

- Per tick, list the consumers per good once, in entity order.
- A producer with output paths only to the consumers that are short right now, the same per-candidate search it already runs toward each goods buffer. A consumer on another road network is skipped without a search: road component labels are worked out once per tick, and only when a candidate needs them.
- There is no cache across ticks. A consumer stays a candidate only while it is short, so the repeated searches are few.
- Shortness is checked live, so a unit dispatched earlier in the tick counts as inbound for the next producer.

The candidate list is small: only consumers of the good that are short. Measured in a release build after a 12,000-tick guided bot game (seed 3), the mean tick went from 0.9 to 1.2 ms on a single island and from 2.0 to 1.9 ms on the archipelago, against a 100 ms budget. So the single-search-plus-cache variant stays in reserve for when profiling asks for it.

### D3. Market hubs (milestone 2)

- **What counts as a hub:** a town center or a `marketplace`, the player's or a rival's. The marketplace is a new building, smaller and cheaper than a town center, so a town can grow beyond one hub. It gets its own canvas, cost and research gate before milestone 2 starts.
- **The marketplace building (M2b):** id `marketplace` (`BuildingKind.marketplace`). Its look is option B from the canvas at https://claude.ai/artifact/XtPfzGyD3oVW5juaZgzP1f: an open market hall on posts with stalls, 2 × 2 tiles, with culture variants. The sprites are `building-marketplace` and `building-marketplace-<culture>`, made by the art agent.
  - **Where porters leave and return:** the building's normal road-access tile, the first road tile next to the footprint (`anyAdjacentRoad`), as for every other carrier. There is no fixed entrance side, so the hall reads as open from every edge.
  - Porters never enter the footprint. Idle porters are not drawn.
- **Shipping together:** milestone 2a (the town center as hub) and 2b (the marketplace) land in the same milestone sequence. The player never gets a build where the town center is the only hub, because one hub can't feed a large merchant town (see Risks, Throughput).
- **Hub radius:** a hub serves the houses whose road path to it is at most `radius` road tiles, read from the hub building's game data (D9). The starting value is 18. A house within reach of several hubs is served by the nearest; ties go to the lower ID.
- **Hub stock:** hubs keep their goods-buffer role. In addition, house goods prefer them:
  - A producer of a house good sends to the nearest hub with room before trying other buffers (D1 step 3, ahead of warehouses).
  - A hub that is low on a house good its houses need pulls from warehouses on its network. Low means below the hub's reserve, 2 consumptions of its served houses. The haul uses a new mission, `.restock(good:amount:fromBuffer:toHub:)`.

### D4. Market porters and house stock (milestone 2)

- **House stock:** each house keeps a stock per need good: `houseStock[good]`. Its capacity is twice the house's current consumption of that good, and at least 2.
- **Consumption:** every 100 ticks a house consumes from its own stock. A shortfall marks the need short, as `setShort` does today. Houses no longer call `World.consume` on buffers.
- **When a need counts as met:**
  - It is met while the last consumption of it was not short, and stock plus inbound porter units covers the next consumption.
  - It turns unmet only when a consumption comes up short. That hysteresis is what prevents flicker.
- **Tier advance:** a house can advance only if a hub that serves it holds the next tier's goods. This replaces `hasGoodInReach`, which looked at warehouses.
- **Porters:**
  - **How many:** each hub keeps porters = 1 + one per 4 houses it serves, up to 8. These are starting values from game data (D9).
  - **Choosing a trip:** an idle porter picks the served house with the lowest stock ratio across its needs. The stock ratio is (stock + inbound) ÷ capacity, taking the lowest over the house's needs the hub holds. Ties go to the shorter path, then the lower house ID.
  - **The trip:** the porter carries one mixed basket: for each need the hub holds, enough to fill the house up to one consumption, at most 10 units in all (game data, D9). It walks there, deposits them into the house stock, and walks back empty.
  - **On the map:** a porter is a carrier whose mission is `.porter(goods:fromHub:toHouse:returning:)`. Its return trip is visible too: a porter with an empty basket.
- **Where the stock lives:** house stock sits in `HousePopulation`, so the inspector can show it. The snapshot carries it.

*Why per-house stock:* without it, satisfaction would flip with every delivery and every meal, and growth timers would reset. Two consumptions of stock give a porter about 200 ticks to come back.

### D5. Handcarts (milestone 3)

- **New field:** `Carrier` gains `vehicle: Vehicle`, with the cases `.onFoot` (the default) and `.handcart`.
- **When a haul uses a cart:** the road path is at least `cartDistance` road tiles (starting value 12), and at least 3 units are ready for the same destination. Ready means the source holds them, and the destination needs or has room for them. The cart takes up to 4 units. Otherwise the haul is on foot with 1 unit.
- **Which hauls:** producer → buffer, producer → consumer, buffer → consumer and, once milestone 2 lands, restock hauls. Porters stay on foot.
- **Pace and cap:** a cart moves at the same one tile per tick as a walker and takes one of the producer's two carrier slots. The difference is visual only.
- **Tuning:** `cartDistance`, the minimum load (3) and the capacity (4) come from game data (D9).

*Why this rule:* it is decided entirely from integer state the source already has, so it stays deterministic. It also means a cart never leaves half-empty on a short trip.

*Rejected:* carts every time a building has 4 units. That would turn every short hop into a cart, and the town would lose its walking carriers.

### D6. Saves

Milestone 1 moves the save version from 9 to 10, with a migration that only bumps the number, so an older build refuses a save that might hold a `deliverToConsumer` carrier instead of failing to decode it. A v9 fixture save checks the step.

All new fields decode with `decodeIfPresent` and defaults:
- `Carrier.vehicle` defaults to `.onFoot`.
- New mission cases simply never appear in old saves.
- `HousePopulation.stock` defaults to empty.

On loading a save from before milestone 2, every house seeds its stock: each need it currently counts as met gets one consumption's worth. Without that, every house would come up short at the first consumption after loading, and towns would decline overnight. A test loads a pre-milestone-2 fixture save and checks that no house turns short within one interval.

### D7. Determinism and coverage

- New loops follow the existing order: entity order, goods in `Good` order, ties by path length and then entity ID.
- No `Dictionary` iteration order and no floating point enter the simulation.
- Each milestone regenerates `DeterminismFixture` on purpose, and the macOS-vs-Linux byte-equality job must pass.
- New CityCore code stays at 100 % diff coverage.

### D8. Rendering

`CarrierRendering` picks a look from the mission and the vehicle:
- carriers keep their load looks (logs, sack, barrel, crate);
- porters show `porter-<facing>-<frame>`, with an empty-basket variant on the way back;
- handcarts show `handcart-<facing>-<frame>` in one generic load look.

The canvas proposes the looks: https://claude.ai/artifact/2pupecCf6JAYUSkfi5LsWp (recommended: the two-wheel handcart and the shoulder-yoke porter). The figures are built in IsoKit like the walkers: 4 facings × 8 frames, a 32 × 32 cell for porters and 64 × 48 for the handcart.

### D9. Tunables live in game data

The distribution numbers are starting values, so they go in the game-data packs, not in Swift constants. designer2 tunes them in the pacing sweeps without a code change.

- **Hubs:** a hub building's pack item gets a `hub` mapping: `radius` (18), `housesPerPorter` (4), `maxPorters` (8), `basketUnits` (10) and `reserveConsumptions` (2). The town center and the marketplace each carry one, so the marketplace can be tuned apart from the town center.
- **Carts:** one `Logistics` item in `core.yaml` holds `cartDistance` (12), `cartMinLoad` (3) and `cartCapacity` (4).
- **House stock:** the same item holds `houseStockConsumptions` (2) and `houseStockMinimum` (2).
- The schema validates them, `make gamedata` generates the Swift catalog, and `gamedata-check` keeps the two in sync.

### D10. "No market in reach" (milestone 2)

There is no warehouse fallback. A house whose road path to every hub is longer than that hub's radius cannot be supplied.

- Such a house gets a building issue, `BuildingIssue.noMarketInReach`, shown the same way as `noRoad`: the issue marker on the map and the line in the inspector ("No market in reach").
- It replaces the house's current check that its road reaches a warehouse, port or town center, and comes after no road: a house without a road shows only that.
- The issue clears as soon as a hub covers the house, for example after the player builds a marketplace.

### D11. Rivals follow the same rules (milestone 2)

Rival towns use the same hubs, porters, house stock and radius as the player; there is no rival shortcut.
- The rival AI already places its town center first. Its house placement must stay within a hub's radius, and it builds a marketplace when houses would fall outside every hub, the way it already builds missing producers.
- **Acceptance:** the rival-viability sweep stays green.

## Risks / Trade-offs

- **Supply latency (milestone 2):** houses now wait for porters. A town whose houses lie far from the town center loses satisfaction it had before.
  - *Mitigation:* tune the radius (18) and the stock (2 consumptions), and give saves the seeded stock from D6.
  - *Gate:* the sweeps (first-hour solvency, mid-game pacing) before and after, compared with designer2's pacing numbers.
- **Throughput (milestone 2):** porter capacity has to cover what the served houses eat.
  - *Demand:* a merchant house of 8 residents eats about 9 units per 100 ticks: 4 food, 1 plank, 2 bread, 1 tools and 1 luxury. 24 merchant houses eat about 2,200 units per 1,000 ticks.
  - *Supply:* at an average house distance of 10 road tiles, a round trip takes about 22 ticks. 8 porters × 10 units every 22 ticks give about 3,600 units per 1,000 ticks; at the full 18-tile radius it is about 2,100.
  - *Consequence:* one town center alone can't feed a large merchant town at the edge of its radius. That is why the marketplace ships in the same milestone (D3).
  - *Gate:* a CityCore test of a town at a hub's capacity limit, and the mid-game pacing sweep.
- **Rival viability:** rivals now depend on porters too (D11). *Acceptance:* the rival-viability sweep stays green.
- **First hour (milestone 2):** a starting town has to be fully covered by its town center hub. *Acceptance:* the first-hour guided sweep stays at 0 of 20 bankruptcies.
- **Intermediates in storage (milestone 1):** fewer intermediates reach warehouses, so sales at the market shift. Watch the first-hour solvency sweep.
  - *M1 result*, PlayerBot sweeps on main 334c173d against the M1 branch, release build:
    - First-hour solvency with the market: 0/20 bankrupt on both.
    - Guided Hard start: 0/20 bankrupt on both, with residents at tick 12,000 identical (min 29, median 52.5).
    - Rival viability: identical (year 5 min 15, median 59.5).
    - Mid-game pacing (a measurement, not a gate): the first merchant came sooner (median 3.95 years against 4.2), but fewer arms reached one (112 of 180 against 120), and bankruptcies rose from 7 to 17 of 180, mostly in the naive build order.
    - A probe of normal/single-island/naive seed 5 shows the mechanism. Iron reaches storage earlier, so the naive bot builds a toolsmith before a brewery, runs short of cash and never gets the beer merchants need. That is build-order sensitivity in the bot, for designer2 to weigh in the pacing work, rather than a starved chain.
- **Performance:** D2's search is per producer with output. Porters add at most 8 carriers per hub. The carrier count stays within today's peak, since direct hops shorten trips.
- **Visual clutter:** more figures on roads. Carts reduce the count on long hauls, and walker density limits still apply.

## Migration Plan

The milestones ship in the order 1 → 3 → 2, each as its own PR:
- **Milestone 1** needs no save migration.
- **Milestone 3** (handcarts) does not depend on the market. It defaults `vehicle` to `.onFoot`.
- **Milestone 2** (2a and 2b together) seeds house stock on load (D6). Its marketplace canvas comes first, and it runs the sweeps before and after.

A milestone can be reverted on its own, apart from milestone 2's save format, which keeps decoding.

## Resolved Questions

The orchestrator settled these on 2026-10-24:
- **Q1. Marketplace:** yes. Milestone 2 includes the marketplace, with its own canvas, and 2a and 2b ship together (D3).
- **Q2. Porter numbers:** 1 + houses/4 (at most 8), 10 units per basket and an 18-tile radius are starting values. They live in game data (D9).
- **Q3. Warehouse fallback:** no. A house out of every hub's reach shows "No market in reach" (D10).
- **Q4. Cart speed:** the same as walkers (D5).
- **Looks:** the two-wheel handcart and the shoulder-yoke porter, including the empty-basket return frames. The new `Figures.swift` poses are coordinated with the art agent before they land.
