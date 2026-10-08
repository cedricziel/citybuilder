## Why

`add-rival-towns` puts AI towns on the archipelago, but the player can only watch them. The game direction asks for rivals that compete for islands *and trade*. Trading with rivals turns them into markets: the player can sell surplus, buy what their own islands lack, and decide whether feeding a rival bread and tools is worth the money when it also helps that rival grow.

This change depends on `add-rival-towns` and lands after it.

## What Changes

- **Rival ports:** a rival with at least 6 houses and no port builds one at the first valid shore spot near its town center ($250, 8 wood, 6 planks, as for the player). Rivals don't need Seafaring.
- **Prices:** every good has a base price (wood $4, planks $8, food $4, bread $12, grain $3, flour $6, ore $5, charcoal $5, iron $14, tools $30). Rivals sell at 125% of base and buy at 75%, rounded down, never below $1. Prices are fixed, so buying from one rival and selling to another always loses money.
- **Offers:** a rival offers to sell any good it holds more than 30 of (the amount above 30). It offers to buy wood, planks, food, bread and tools up to 20 in stock. Offers are worked out from the rival's island stock whenever they are needed, never stored.
- **Trading by ship:** a player route may stop at a rival port. There, the route's manifest becomes trade: "load" buys from the rival and "unload" sells to it, limited by the offer, the ship's cargo or space, the buyer's money and the rival's storage. Money moves between the player's balance and the rival's treasury, and each trade emits `tradeCompleted`.
- **Rival growth through trade:** rival houses already climb to merchants when bread and tools are in stock, so selling them bread and tools lets them grow past citizens.
- **UI:** the inspector on a rival port shows its market (sells and buys with price and quantity). In the manifest editor a rival port's actions read Buy and Sell, with the current price and offer.
- **Saves:** no version bump. Ports are ordinary buildings, offers are derived, and the two new AI counters decode as 0 when missing.

Deferred: rival ships and rivals trading with each other, rivals buying or selling at the player's ports, prices that move with supply, trade treaties and embargoes.

## Capabilities

### New Capabilities

- `rival-trade`: rival ports, base prices, offers and trades at rival ports.

### Modified Capabilities

- `sea-transport`: manifest actions at a rival port are trades.
- `platform-shells`: rival market in the inspector, Buy and Sell in the manifest editor.

## Impact

- **CityCore:** `Good.basePrice`, `RivalTown` offer queries (`sellOffers`, `buyOffers`), the AI port rule and shore spot search, owner-aware manifest execution in `ShipTick`, `WorldEvent.tradeCompleted`.
- **CityUI:** inspector market section, manifest editor labels and prices.
- **CityPersistence:** none.
