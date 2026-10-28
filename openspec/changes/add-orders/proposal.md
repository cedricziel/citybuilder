## Why

Money comes from tax, caravans, the town market and rival ports, and all of it is open-ended: nothing asks the player for a good by a date. Since per-good storage, a full store stops its producer, and the town market no longer pays enough to be a reason to produce (#268). The slow mid-game that the owner asked for (6–8 years to the Renaissance) is a climb with no beats between "first merchant" and "next age".

Orders give that climb beats. The crown and the rival towns ask for a quantity of a good by a date and pay for it. Surplus that backpressure would have stopped gets a purpose, and the player has something to plan production around. The Merchant Sea chapter 3 of the campaigns (`add-campaigns`) cannot ship without them.

## What Changes

- **Orders.** An order asks for N of a good by a deadline and names its reward. It is issued by the crown or by a rival town, sits on a small board as an offer, and the player accepts or ignores it. At most 2 accepted orders are open at once.
- **The crown** sends one order a year from the second year (every 4 seasons in Antiquity and the Middle Ages, every 3 in the Renaissance, every 2 in the Industrial and Modern ages; scaled by difficulty). It delivers to a town center.
- **Rivals** post an order for a good they are short of, by the shortage rule their standing offers use. It delivers by ship to that rival's port, through the ordinary trade at the port.
- **Order size follows the town.** An order asks for a share of what the town has made of that good over the last four seasons, scaled to the order's window, and never more than three quarters of what the town's stores can hold of that good. The town has to make the good to be asked for it.
- **Visible delivery.** The player sends a crown order from the board. Goods leave the stores that hold them and walk the roads to the town center as order carriers. A shipment is all or nothing and is refused if it would arrive after the deadline. A rival's order is filled by the player's ships unloading at that rival's port.
- **Rewards and favour.** Fulfilling an order pays money (a percentage of the goods' base price) and raises the issuer's favour. A late or failed accepted order costs favour and never money.
- **Favour** is a small whole number per issuer, from −10 to 20. High crown favour lowers research cost by 3% and then 5%. High rival favour improves prices at that rival's port by 5% and then 10%.
- **Data.** Order templates, with the good, the window, the size and reward shares, are a new `Order` item kind in a game-data pack. The Age item gains `orderEvery`, the seasons between crown orders. The rest of the rules (open limit, board size, favour steps) are constants with named scenarios.
- **Goals.** A new `orders` goal, "fulfil N orders", for scenarios and the campaign chapters Merchant Sea 3 and 5 and Chronicle 4.
- **UI (after the canvas is approved).** An order board, notifications when an order is offered, fulfilled or missed, and an orders chip in the HUD, on iOS, macOS and tvOS.

Out of scope:
- mainland traders as a third issuer; the crown carries the mainland flavour, and #263 (rival attitudes) can add more issuers;
- one-off unlocks and building discounts as rewards;
- negative-favour penalties other than the lost bonuses (#263 reads favour later);
- orders delivered by sea to the player's own other towns.

## Capabilities

### New Capabilities
- `orders`: templates, issuing, sizing, the board, accepting, delivery, rewards, penalties, favour and the orders goal's counter.

### Modified Capabilities
- `rival-trade`: "Trading at a rival port" lets a rival buy above its standing target for an accepted order and counts the units toward it; new "Favour improves a rival's prices".
- `research`: "Research cost scales with difficulty" gains the crown's favour discount.
- `difficulty-and-goals`: new "Orders goal".
- `platform-shells`: new "Order board", "Order notifications" and "Orders chip in the HUD".
- `persistence-save-load`: new "Saves before orders have none".
- `world-events`: new "Order events".

## Impact

- **CityCore:** new `Orders.swift` (state, templates API, rules), `World+Orders.swift` (issuing, commands, shipments, settlement), a new tick step after the calendar, new `Command` and `WorldEvent` cases, a one-line change in `Systems/RivalTrade.swift` and `Research.swift`, and `Goal.orders`. Orders live in their own files and their own tick step; they do not touch the carrier system, so the direct-hops work (#232) and the carrier code are unaffected.
- **Game data / GameDataGen:** a new `Order` item kind, an optional `orderEvery` on `Age`, a new `orders` pack, the schema, the generated `OrderTemplate` catalog.
- **Saves:** additive. A save without orders decodes an empty state, so there is no version bump (design D12); old saves with an active calendar get orders from the next season.
- **Determinism:** orders only run in games with an active calendar. The order RNG is derived from the seed and the order number and never draws from the world's RNG, so nothing that does not use orders changes. The determinism fixture's JSON gains the (empty) orders state; a game that makes orders is covered by the `orders are deterministic` test and, over whole games, by the bot sweeps.
- **PlayerBot / sweeps:** an `OrdersKit` (accept what the town can fill, send when stocked). Before and after sweeps for first-hour solvency, rival viability, the market control and mid-game pacing are in the PR.
- **CityUI, CityRender2D, `design/web`:** board, notifications, HUD chip; order carriers are drawn with the existing carrier figures. Needs a Claude Design canvas first.
