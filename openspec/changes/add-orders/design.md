## Context

Orders are roadmap item 1 of the campaign design (#255, `add-campaigns` D12). The campaign chapter Merchant Sea 3, "Orders from the Mainland", has the goal "fulfil 6 orders" and can't ship without this change.

What exists today:

- Carriers walk single units from a producer to a store, a consumer or a construction site. One mission enum, one system, and the direct-hops work (#232) is changing both.
- Stores keep each good apart (`storagePerGood`, 40 at the town center, 80 at warehouses and ports), and a producer whose output has nowhere to go stops. The statistics screen records, per season, the units of each good the player's producers made.
- A rival posts standing offers: it sells stock above 30 and buys wood, planks, food, bread and tools up to 20 (`RivalMarket`). Player ships trade at its port through `applyTrade`.
- The town market sells at 150% and buys at 50% of the base price, with seasonal limits, and has no solvency role since per-good storage (#268).
- The calendar has seasons of 600 ticks and years of 2,400. Fixtures leave it inactive.

## Goals / Non-Goals

**Goals:**
- Timed requests that give surplus a purpose and give the mid-game beats, without speeding the mid-game up or bankrupting anyone.
- Visible delivery to the town center, by order carriers on the roads.
- Content in game data: templates, cadence per age.
- Orders as a separate system with its own files and tick step.
- A counter the campaigns' "fulfil N orders" goal reads.

**Non-Goals:**
- Mainland traders as an issuer, unlocks and discounts as rewards, negative-favour penalties beyond the lost bonuses, orders between the player's own towns.
- Changes to the carrier system, the market, the rival AI's build script or the research tree.

## Decisions

### D1. Two issuers: the crown and the rivals

- **The crown** is always there, in every layout. Its orders deliver to a town center.
- **A rival** posts an order for a good it is short of, so an order has a reason a player can read ("Rival 1 is short of planks"). They exist only on archipelagos, so a single-island game has crown orders only.
- Mainland traders are left out: the crown covers the mainland's voice in the chapter text, and a third issuer is one more `OrderIssuer` case later (#263).

### D2. Orders are offers on a board; the player chooses

- An order starts as an **offer**. It lapses at the end of the season it was issued in, unless accepted. Ignoring an offer costs nothing.
- The board holds at most 3 offers. A new order is skipped while the board is full.
- The player has at most 2 **accepted** orders. This is the commitment: accepting is what makes a miss cost favour.
- The deadline is fixed when the order is issued, a season boundary, so "by spring" is a date on the calendar and accepting late leaves less time.

### D3. The schedule comes from the calendar and the age

- Orders are issued at season boundaries (`tick % 600 == 0`), so cadence needs no stored timer.
- **Crown:** from season 4 (the start of year 2), every `n` seasons, where `n` is the age's `orderEvery` scaled by the difficulty's cadence percent (150, 100, 75), rounded to the nearest whole number and at least 1.
  - `orderEvery` is a field of the Age item: Antiquity 4, Medieval 4, Renaissance 3, Industrial 2, Modern 2.
- **Rivals:** each rival, every 2nd season staggered by its ID, if it has no open order and is short of a good that has a rival template for its age.
- Both stop when the game is over, and nothing runs while the calendar is inactive (fixtures keep their meaning; `newGame` and the v5 migration activate it).
- The order of issuing in one season is fixed: the crown first, then the rivals by ID.

### D4. Order templates are game data

An `Order` item in a pack is a template:

| Field | Meaning |
|---|---|
| `issuer` | `crown` or `rival` |
| `good` | the good asked for |
| `title`, `text` | the card heading and one line of flavour (≤ 100 characters) |
| `minAge` | the first age it appears in (optional, default the first age) |
| `seasons` | the window: seasons from issue to the deadline, before the difficulty scales it (D5) |
| `size` | percent of the town's recent output over the window that the order asks for |
| `min`, `max` | bounds on the quantity in units |
| `reward` | money paid, as a percent of the goods' base price |
| `favour`, `penalty` | favour gained on fulfilment and lost on a miss (optional, default 2 and 2) |

The v1 pack has six crown templates (wood, planks, food, bread, iron, tools) and five rival templates (wood, planks, food, bread, tools; the goods a rival buys). The campaign chapters and #273 (cloth) add templates later by adding items; no code changes.

Rules that are not content, because they define the system rather than tune it, are constants in `OrderRules` with scenarios: the open limit 2, the board size 3, the offer length 1 season, the rival slot every 2 seasons, the output window of 4 seasons, the 75% store cap, and the favour range and steps.

### D5. Size follows the town's output (achievable but demanding)

For a template `T` and the player's town:

1. `recent` is the units of the good the player's producers made over the last up-to-4 closed seasons (`statistics`), `seasons` is how many of those seasons exist.
2. Not eligible unless at least 1 season is closed and `recent` is positive: the town has to make the good.
3. `units = recent × T.seasons × T.size / (seasons × 100)`, then times the difficulty's size percent (80, 100, 120) over 100.
4. `cap` is 75% of what the player's stores can hold of the good, summed (`Stockpile.capacity` of each operational store): for a crown order the town centers and the stores road-connected to one, for a rival's order every store, since its goods go by ship. The quantity is `min(units, T.max, cap)`.
5. Not eligible when the quantity is below `T.min`.

The deadline is the end of the season `window` seasons after the issue, where `window` is `T.seasons` times the difficulty's window percent (130, 100, 85) over 100, rounded to the nearest whole season and at least 1. The difficulty changes the time and the quantity, never the reward.

So an order never asks for more than the town makes in the window at its size share, and never for more than the stores can hold, which is what per-good storage needs: a 40-unit town center cannot be asked for 60 planks. The order rewards a town for what it already does, and a player who diverts the good from houses and construction pays for it.

A rival order uses the same size rule; it is also eligible only if the rival's treasury pays the whole quantity at its buy price.

The "recent output" is deliberately the observed output, not the nominal capacity of the producers: stalled workshops don't inflate it. The cost is that a new chain is invisible for a season, which is fine; an order appears once it matters.

### D6. Rewards and penalties

- **Reward:** money = `quantity × basePrice × T.reward / 100`, paid when the order is fulfilled. The crown's templates pay 120–135% of base against the market's 50%, so an order is the best outlet for surplus. A rival pays the ordinary 75% at its port for each unit, and the order's `reward` (about 40%) comes on top.
- **Favour:** `+T.favour` to the issuer on fulfilment.
- **Penalty:** an accepted order that is not complete when its deadline passes, or that the player abandons, costs `T.penalty` favour. Never money. Goods are never confiscated: the crown's shipment is all or nothing (D7), and a rival's units were paid for at the port as they were sold.
- Favour is clamped to −10…20.

The first values for `reward`, `size` and the difficulty percents are starting points. Task 5.2 tunes them against the bars in D11 and writes the result into this section.

### D7. Delivering to the crown: shipments from the stores

Delivery is one command, `dispatchOrder`, so the player decides when the goods leave and the stores are never raided by a timer.

- **Plan:** `orderDispatchPlan(for:)` lists the operational player stores that hold the good and are road-connected to a player town center, nearest first (path length, then entity ID), and takes units from each until the quantity is met. It returns nothing, and the command does nothing, when:
  - the order is not an accepted crown order that has nothing sent yet;
  - the stores together hold fewer units than the quantity;
  - a leg has no path to a town center;
  - the longest leg would arrive after the deadline (a path of n tiles arrives n − 1 ticks after the dispatch).
- **All or nothing** means a partial shipment never exists, so a missed deadline never swallows goods (see D6). The UI shows the plan as "In stores 24 of 30" and enables the button at the full amount.
- **Execution:** the units leave the stores at once and travel as **shipments**: one per store, with a path along the roads to the nearest town center, advanced one tile a tick like a carrier. A store that is the town center itself counts immediately. Shipments are state in `OrdersState`, not `Carrier`s, so the carrier system and its missions are untouched.
- **Arrival** adds the units to the order. The order is fulfilled in the same tick when the units reach the quantity. A shipment whose order has closed meanwhile (not expected, since a shipment is refused if it would be late) goes back into the store it left. A shipment whose town center was demolished while it walked still counts: the crown's agent was already on the road.
- **Drawing:** the snapshot appends the shipments to `carriers`, with a `deliver` mission to the town center, so the renderer draws them as the carriers it already has. The canvas decides whether they need their own look (D13).
- **Per-good storage:** a shipment frees room for the good in the stores it drew from. A producer stopped by backpressure resumes. That is the point of "surplus gets a purpose".

### D8. Delivering to a rival: by ship, through the port trade

- The player's route already unloads at a rival's port. `sell` in `Systems/RivalTrade.swift` gets one change: while the player has an accepted order from that rival for the good, the rival's buy demand for it is the larger of its standing demand (up to 20) and the order's remaining units. Those units are paid at the ordinary price like any sale, and they count toward the order.
- Fulfilment pays the order's reward on top. A rival that cannot pay stops the sale as today, and the order keeps waiting for the deadline.
- No new ship machinery: a player with a route to that port has the means; one without cannot fill it and ignores it.

### D9. Favour and its perks

- One number per issuer: the crown and each rival. It is part of `OrdersState`.
- **Crown:** at favour 6, research costs 3% less; at 12, 5% less. Applied after the difficulty's percent, rounded down.
- **Rival:** at favour 6, that rival sells for 5% less and buys for 5% more; at 12, 10%. Rounded down and at least $1, the same as the base price rule.
- The perks are small on purpose; they are the long-term reason to fill orders, not a shortcut. Research cost is one of the levers of the 6–8 year target, so the sweeps cover it.
- Negative favour has no effect of its own yet. It lowers the player's standing in the board's readout and is the signal #263 reads.

### D10. Where it lives in the tick

A new step, `runOrderSystem`, runs after the calendar and before the goal system:

1. advance the shipments and settle arrivals;
2. fulfil accepted orders that reached their quantity (a rival's units arrive through the port trade earlier in the tick);
3. fail accepted orders past their deadline; lapse offers past their end;
4. at a season boundary, issue the crown's order, then the rivals';
5. nothing else, and nothing at all when the game is over or the calendar is inactive.

Commands (`acceptOrder`, `declineOrder`, `abandonOrder`, `dispatchOrder`) are applied with the other commands at the start of the tick. A command that fails its checks is dropped without effect, like a rejected placement.

The order RNG is `DeterministicRNG(seed &+ (orderNumber + 1) &* 0x9E37_79B9_7F4A_7C15)`, derived like the history event's, and the world's RNG is never drawn from. A game that ignores its orders therefore plays exactly as one without orders, apart from the orders' own state.

### D11. Balance bars and the sweeps

Orders must not bankrupt towns or shorten the climb. With the PlayerBot's `OrdersKit` on (accepts any order whose quantity is at most 1.5 times the stock plus the output of its window, sends when stocked), against main with no orders:

- **First hour:** the Hard guided start stays solvent and grows (10 seeds, both layouts) and the first-hour control (archipelago seeds 0–29, Normal, 4,000 ticks) shows no more bankruptcies.
- **Rivals:** the rival viability sweep is unchanged (rivals are not affected unless the player accepts a rival's order).
- **Solvency:** the market-trading sweep (10 seeds, both layouts, 36,000 ticks) has 0 bankruptcies.
- **Pacing:** the mid-game pacing sweep keeps the median Renaissance between 6 and 8 years on Normal, and the share of arms that reach a merchant does not fall.
- **Order health:** at least half of the orders the kit accepts are fulfilled, so orders are achievable; fewer than all, so they are demanding.

The tables, before and after, go in the PR.

### D12. Saves and determinism

- `World.orders` is an additive Codable field. A decode overload (the pattern of `market` and `statistics`) turns a missing key into an empty `OrdersState`. Nothing else in a save changes, so there is no version bump and no clash with the other in-flight changes that take version numbers.
- An old save with an active calendar starts issuing orders at the next season boundary after its year-2 mark; the schedule is derived from the tick count, so it needs no stored state.
- Orders only run with an active calendar, so fixtures and tests that don't set one are unaffected. The determinism fixture's JSON gains an empty `orders` key, because its town never makes goods; favour is written under string keys so equal worlds encode to equal bytes. Orders over whole games are replayed by the bot sweeps and by the `orders are deterministic` test.

### D13. UI is gated on the canvas

The board, the notifications and the HUD chip are a new panel and a HUD change, so they need a Claude Design canvas first (CLAUDE.md). The sim and the bot were built while it was reviewed. The canvas compared the current HUD with three options (a side board, a ledger sheet, a notice strip). **Option A was approved: a chip in the HUD and a glass board on the trailing edge, with parchment banners for notifications.**

**Layout (condition of the approval).** The trailing edge is shared with the minimap, the first-steps card and the inspector callout, so the board's frame is computed beside theirs (`OrderBoardLayout`, in the style of `MinimapLayout`) and never overlaps the minimap, the build rail or dock, or the tool strip. The first-steps card collapses while the board is open. In regular widths the callout places itself outside the board's frame and both stay open. In a compact width one replaces the other, and on a phone in portrait the board is a sheet. The canvas's "Built" artboard shows this layout with before and after shots once it is built. Order carriers are drawn with the existing carrier figures first; the canvas may ask for a sealed-satchel or banner variant, which would be an art task of its own.

### D14. Campaign goal

`Goal.orders(N)` is met when `OrdersState.fulfilledCount` reaches N. The count covers all issuers and survives a save. Campaign chapters set their own order cadence through the pack when `add-campaigns` lands; this change only provides the counter and the goal.

## Risks / Trade-offs

- **[Risk]** Orders speed up the mid-game through rewards and the favour discount. → Rewards are paid for goods that would otherwise feed houses and construction; the discount is 3–5%; pacing is a sweep bar (D11), and the numbers in D4 are tunable data.
- **[Risk]** A reward large next to a young treasury could make rushing orders the best opening. → Crown orders start in year 2, are sized from observed output, and bots are measured for solvency and pacing.
- **[Risk]** An order for the same good as the houses' needs starves houses. → The player chooses when to dispatch, and the plan shows what is in the stores; the order never draws without the command.
- **[Risk]** Shipments and carriers drawn alike confuse a reader of the map. → The canvas decides on a mark; the sim is unaffected.
- **[Trade-off]** Output-based sizing hides orders from towns that have just started a chain. Accepted: orders follow established production.
- **[Trade-off]** All-or-nothing dispatch can be refused although most of the goods are there. Accepted: it keeps forfeits impossible, and the readout shows the shortfall.

## Migration Plan

No version bump (D12). A save from before this change loads with an empty board, and orders begin at the next season boundary on or after the start of year 2 of its calendar. The order-less behaviour of a game that ignores orders is unchanged.

## Open Questions

- Does Merchant Sea 3 want its own cadence (an order every season)? Decided when the chapter is authored, as pack data on the chapter.
- Should a third issuer, the mainland trader, arrive with #263? Decided there.
