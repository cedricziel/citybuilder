## Context

See proposal.md (Why). After `add-rival-towns`: buildings and ships have an `Owner`, each rival has a `treasury`, an island and a rule-based AI (`RivalAIState`, threshold rules then a script), and rivals build only houses, roads, lumberjack huts, sawmills, farms and warehouses. Placement for rivals skips research.

Sea transport today: a `Route` lists waypoints (`.sea`, `.port(id)`) and a per-port manifest of `loadUpTo(good, qty)` / `unloadUpTo(good, qty)`. When a ship docks, `applyManifestAction` moves up to `qty` units between the ship and **that port's own stockpile**, and returns whether anything moved. An action that moves nothing waits under the dock timeout (3,000 ticks). Route validation only needs each `.port(id)` to be an existing port.

## Decisions

### D1 — Rivals build a port

A new AI rule sits after the threshold rules and before the script: **no port and at least 6 houses → port**. Like threshold rules it does not advance the script.

The port doesn't use the block grid. The AI scans anchors in a square spiral around its town center anchor (the same perimeter-by-radius order `findFootprint` uses) out to radius 40, and takes the first anchor where `canPlace(.port, at:, for: rival)` is allowed. Affordability is the usual rule: treasury ≥ $250 + $50 and island stock covers 8 wood and 6 planks. If no anchor exists, the rule counts as waiting; after 10 waiting turns the rule is suspended for 100 turns so the script keeps running. `RivalAIState` gains `portWaitTurns: Int` and `portRetryTick: UInt64`, both decoded as 0 when missing, so saves from `add-rival-towns` load without a version bump.

The rival port needs no road. Trades read and write the rival's whole island stock (D4), so the port is only a place to dock.

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
