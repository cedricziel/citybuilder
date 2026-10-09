## Context

See proposal.md (Why). After `add-rival-towns`: buildings and ships have an `Owner`, each rival has a `treasury`, an island and a rule-based AI (`RivalAIState`, threshold rules then a script), and rivals build only houses, roads, lumberjack huts, sawmills, farms and warehouses. Placement for rivals skips research.

Sea transport today: a `Route` lists waypoints (`.sea`, `.port(id)`) and a per-port manifest of `loadUpTo(good, qty)` / `unloadUpTo(good, qty)`. When a ship docks, `applyManifestAction` moves up to `qty` units between the ship and **that port's own stockpile**, and returns whether anything moved. An action that moves nothing waits under the dock timeout (3,000 ticks). Route validation only needs each `.port(id)` to be an existing port.

## Decisions

### D1 — Rivals build a port

A new AI rule sits after the threshold rules and before the script: **no port and at least 6 houses → port**. Like threshold rules it does not advance the script.

The port doesn't use the block grid. The AI scans anchors in a square spiral around its town center anchor (the same perimeter-by-radius order `findFootprint` uses) out to radius 40, and takes the first anchor where `canPlace(.port, at:, for: rival)` is allowed. Affordability is the usual money rule: treasury ≥ $250 + $50. A rival's port costs no materials, like a rival's lumberjack hut (see Implementation notes). If the rival can't pay or no anchor exists, the rule counts as waiting and takes the turn; after 10 waiting turns the rule is suspended for 100 turns so the script keeps running. `RivalAIState` gains `portWaitTurns: Int` and `portRetryTick: UInt64`, both decoded as 0 when missing, so saves from `add-rival-towns` load without a version bump.

The rival port needs no road. Trades read and write the rival's whole island stock (D4), so the port is only a place to dock. Without a road no carrier can bring a construction site its materials, which is why the rival's port costs none.

- **Alternative — seed a port for each rival at new game.** Rejected: rivals from `add-rival-towns` saves would never get one without a world-aware migration, and a port from turn one would make early trade too easy.
- **Alternative — trade at the rival's town center.** Rejected: ships can only dock at ports, and the port is a visible "open for business" sign on the map.

### D2 — Base prices

`Good.basePrice: Int64`: wood 4, planks 8, food 4, bread 12, grain 3, flour 6, ore 5, charcoal 5, iron 14, tools 30. A rival's sell price is `max(1, base * 5 / 4)` and its buy price is `max(1, base * 3 / 4)`:

| Good | Rival sells at | Rival buys at |
|---|---|---|
| wood | 5 | 3 |
| planks | 10 | 6 |
| food | 5 | 3 |
| bread | 15 | 9 |
| grain | 3 | 2 |
| flour | 7 | 4 |
| ore | 6 | 3 |
| charcoal | 6 | 3 |
| iron | 17 | 10 |
| tools | 37 | 22 |

Every `Good` case must have a base price; a test walks `Good.allCases`. If `add-culture-content` lands first, its raw goods get base 4 and its luxuries base 20.

Prices are the same for every rival and never change, so sell is always above buy and no loop of trades creates money.

- **Alternative — prices that rise as a rival's stock falls.** Rejected for this slice: harder to show and to test; a later change can add it on top of the same offer queries.

### D3 — Offers

Offers are computed on demand from the rival's island stock (all goods buffers on the rival's island) and never stored:

- **Sells:** every good with stock above 30; quantity = stock − 30.
- **Buys:** wood, planks, food, bread and tools; quantity = 20 − stock when positive.

The sell reserve (30) is above the buy target (20), so a rival never offers to buy and sell the same good. Offers are listed in `Good.allCases` order.

Bread and tools are on the buy list although the rival can't make them: they are what its houses need to become merchants, so selling them is how the player can help (or unwisely feed) a rival.

### D4 — Trades at a rival port

`applyManifestAction` branches on the port's owner. A player port behaves as today. At a rival port, and only for a player-owned ship:

- **`loadUpTo(good, qty)` buys.** Units = min(qty, ship free space, sell offer quantity, player balance ÷ sell price, rounded down; 0 when the balance is not positive). Units are withdrawn from the rival's island buffers in ascending entity ID order. The player's balance drops and the rival's treasury rises by units × sell price.
- **`unloadUpTo(good, qty)` sells.** Units = min(qty, cargo of that good, buy offer quantity, rival treasury ÷ buy price, rounded down; 0 when the treasury is not positive, free space in the rival's buffers). Units go to the rival's town center first, then its warehouses in ascending ID, then its port. The rival's treasury drops and the player's balance rises by units × buy price.
- **Events.** Each action that moves at least one unit emits `tradeCompleted(rival:good:quantity:total:direction:)`, with `direction` `.bought` or `.sold` from the player's point of view.
- **Waiting.** An action that moves nothing behaves exactly like a stalled load or unload at a player port: it waits under the dock timeout.
- **Game over.** With `economy.gameOver` set, no trade moves anything.

Routes need no new validation: `.port(id)` already accepts any existing port, which now includes rival ports.

- **Alternative — new manifest verbs `buy` / `sell`.** Rejected: the port's owner already says whether goods change hands for money, and reusing the verbs keeps existing routes, validation and the editor working.
- **Alternative — trade against the rival port's own stockpile.** Rejected: rival goods sit in the town center and warehouses, and the port has no road, so it would never hold anything to sell.

### D5 — UI

- **Inspector:** on a rival port, a "Market" section lists "Sells" rows ("Wood — $5 — 12 available") and "Buys" rows ("Tools — $22 — wants 20"). Empty lists read "Nothing for sale" / "Buying nothing".
- **Manifest editor:** for a rival port, the action picker labels read "Buy" and "Sell" instead of "Load" and "Unload", and each good row shows the current price and offer quantity. Goods without an offer stay selectable (the offer may appear later) and show "no offer".
- **Route authoring:** rival ports are tappable like player ports.

## Risks / Trade-offs

- **[Risk] The player drains a rival's treasury by selling, stalling the rival.** → Accepted: rivals earn tax, and the buy targets (20) cap how much they take per good.
- **[Risk] Rivals rarely hold more than 30 of anything, so there is little to buy.** → Mitigation: the runtime check records rival stock and offers after 6,000 ticks; the reserve is one constant.
- **[Trade-off] Rival ports may sit on a shore far from the town.** The port only marks the trading point, so distance doesn't matter for gameplay; it can look odd.

## Implementation notes

- **Rival ports cost no materials (deviation from the first draft of D1).** The draft charged a rival 8 wood and 6 planks from stock. A headless run (below) showed the rival's buffers almost never hold that much at once: its huts and sawmills feed construction as fast as they produce, and the wood threshold rule takes the turn whenever wood is under 4. With the materials rule, no rival built a port in 20,000 ticks. `World.materialCost(of:for:)` now returns no materials for a rival's port, as it already did for a rival's hut; the player's port still costs 8 wood and 6 planks.
- **Island stock means the rival's own buffers.** Offers and trades use `World.rivalStock`: the rival's town center, warehouses and port. The AI's spending checks still use `islandStockpile`; for a rival the two agree outside tests (rivals build no shipyards, and test material credits only exist in fixtures).
- **Route validation measures a port waypoint from its docking tile.** `validate(route:)` used each port's anchor tile, which is land for a port whose top-left tile is on the shore, so routes between real ports could fail the land-crossing check while ships and the route overlay already used the docking tile. `waypointPosition` now returns `shipTargetPosition`, so the "Route to a rival port is valid" scenario holds.
- **Port anchors on water.** `canPlace` looks a building's materials up on its anchor tile's island. Since a rival's port has no materials, that lookup doesn't matter for rivals. For the player, a port whose anchor tile is water still fails the material check; that pre-existing quirk is outside this change.
- **Base prices of culture goods.** `Good.basePrice` already existed from `add-culture-signatures` (caravans) and is reused unchanged: the culture raw goods are $3 and the luxuries $16, not the $4 and $20 the D2 note suggested.
- **UI.** The inspector shows the Market section on a rival port. The app shells have no route-authoring mode or manifest-editor view yet (`RouteAuthoringViewModel` is not wired into any scene), so Buy/Sell labels, prices and offers live in `ManifestEditorModel`, and `RouteAuthoringTapTarget.resolve` classifies taps on ports of any owner. Both are ready for a view to bind to.
- **Headless run (task 4.1 data, not the runtime check).** Normal archipelago, seed 0, no player commands except a player port at the first shore spot on the home island, debug build:
  - At 6,000 ticks neither rival has a port: rival 1 has 4 houses and $56, rival 2 has 3 houses and $190. Both hold no goods, so they sell nothing and buy the full list (wood, planks, food and bread 20 each at $3/$6/$3/$9, tools 20 at $22).
  - Rival 1 reaches 6 houses at about tick 13,000 with under $300, waits 10 turns, is suspended until tick 18,600 and places its port on tick 18,601. Rival 2 stays at 3 houses through tick 20,000.
  - A player route from tick 18,601 (load 40 planks at home; at rival 1, sell up to 40 planks, then buy up to 20 wood) sold 19 planks for $114 on tick 18,843. Rival 1 had no wood surplus, so the buy action waited out the 3,000-tick dock timeout; by tick 20,000 rival 1 had 11 houses, $212 and 4 planks.
  - Rival growth, not the trade rules, limits trade: rivals stay small and cash-poor, so they rarely have anything to sell.
