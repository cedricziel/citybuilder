## Why

A market purchase goes only into the town center, and a town center holds 40 units. When planks or wood fill it, an emergency food buy fails, even though a warehouse on the same island has room (#70, found by the market balance harness in #58). Selling already draws from every player store on the island, so the two directions treat the same stores differently.

## What Changes

- A `marketBuy` fills the operational player goods buffers on the town center's island: the town center first, then the others in ascending entity ID order. The limits, prices and money rules stay as they are.
- The market panel's Buy buttons stay enabled while any of those buffers has room, not only the town center.

Out of scope: rival market trades, which keep buying into the rival's town center (`rival-towns` / Rival market trades), and road connectivity, which selling does not check either.

## Capabilities

### New Capabilities
- (none)

### Modified Capabilities
- `town-market`: "Buying at the town center" fills the island's buffers.
- `platform-shells`: "Town center market panel" disables Buy only when every buffer on the island is full.

## Impact

- **CityCore**: `World+Market.swift` (the buy deposit and `MarketReach.freeSpace`).
- **CityUI**: none in code; the panel reads `MarketReach.freeSpace`, which now covers the island.
- **Determinism**: the `DeterminismFixture` has no market commands, so its output does not change.
