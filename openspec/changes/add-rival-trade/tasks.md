## 1. M1 — Prices, offers and the rival port

- [x] 1.1 Tests-first: translate the rival-trade scenarios "Rivals build a port", "Base prices" and "Rival offers" into failing `CityCoreTests`. Confirm red.
- [x] 1.2 Implement to green: `Good.basePrice`, sell and buy prices, `sellOffers` / `buyOffers`, the AI port rule with the spiral shore search, `RivalAIState.portWaitTurns` and `portRetryTick` with tolerant decoding (design D1–D3).

## 2. M2 — Trading

- [x] 2.1 Tests-first: translate "Trading at a rival port" and the sea-transport scenarios into failing `CityCoreTests`. Confirm red.
- [x] 2.2 Implement to green: owner-aware `applyManifestAction`, island withdrawals and deposits in ID order, money transfer, `WorldEvent.tradeCompleted` and its sort key, the game-over guard (D4).
- [x] 2.3 Add a determinism test: two Hard archipelago worlds with a player route to a rival port stay equal over 3,000 ticks.

## 3. M3 — UI

- [x] 3.1 Tests-first: translate the platform-shells scenarios into failing `CityUITests`. Confirm red.
- [x] 3.2 Implement to green: inspector Market section, manifest editor Buy/Sell labels with prices and offers, rival ports as route-authoring targets (D5).

## 4. M4 — Verification

- [ ] 4.1 Runtime check: in a Normal archipelago game, wait until a rival builds its port, inspect its market, build a route from your port to it that sells planks and buys a surplus good, and watch the balance and the rival's wealth in the standings change when the ship docks. Record rival stock and offers after 6,000 ticks.
- [ ] 4.2 Run lint, format, `make test`, `make test-scenarios` and `openspec validate add-rival-trade --strict`.
