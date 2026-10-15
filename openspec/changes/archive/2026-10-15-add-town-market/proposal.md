## Why

Money has nothing to buy except buildings, and a town short of a basic good has no way out on a single island. In the playtest behind `add-forestry`, a town sat on $2,303 for 15 in-game years with no wood, because only a lumberjack hut makes wood and the hut needed wood. `add-forestry` removes that particular trap. But any shortage of wood, planks or food still stops a town until its own producers catch up, and surplus goods have no use unless the player runs ships to a rival port or plays the one culture with a caravanserai.

## What Changes

- Every player town center becomes a **market**. The player can buy wood, planks and food into it, and sell any good from the goods buffers on its island, for money, at once, without ships or roads.
- **Prices** come from each good's existing `basePrice`. The market sells at 150% and buys at 50%, rounded down, at least $1. It is the worst channel both ways: rivals sell at 125% and buy at 75%, and caravans pay 100%. Rival trade and the caravanserai keep their value, and no chain of trades can make money from nothing.
- **Seasonal limits**: per good and per season, the market sells at most 10 units of each buyable good to the player and buys at most 20 of each good from the player. The limits are per player, not per town center, and reset when the season changes. One lumberjack hut cuts about 80 wood a year, while the market supplies at most 40 a year at $6 each, so the forester and hut stay the way to supply a town. The market only bridges a shortage.
- **Content**: each good's market terms (`market: { buy, sell }`, both seasonal limits) live in its `Good` item in the packs. A good without `buy` cannot be bought, and one without `sell` cannot be sold. Bread, tools and luxuries cannot be bought, so tier chains cannot be skipped. The 150%/50% spreads are rules in Swift, next to the rival trade spreads.
- Trades are player commands applied at the next tick. Each trade moves what the money, the limit, the town center's free space (when buying) and the island's stock (when selling) allow. It emits `marketTraded`. No trade happens after game over.
- The town center's inspector gets a market section that lists each good's price and what is left this season, with Buy and Sell buttons.
- Rivals do not use the market, and the market does not affect rival prices.

## Capabilities

### New Capabilities
- `town-market`: the town center market. Covers what can be traded, prices, seasonal limits, how a trade moves goods and money, the market state in the snapshot and in saves, and the `marketTraded` event.

### Modified Capabilities
- `economy`: market spending and income are booked to the balance outside tax and upkeep, like caravan income.
- `platform-shells`: the town center inspector shows the market and lets the player trade.

## Impact

- **Content and generator**: the `Good` kind gains an optional `market` object (`buy`, `sell`: non-negative seasonal limits) in `pack.schema.json`, the GameDataGen model, validator and Swift emitter (`Good.marketTerms`). `core.yaml` and the four culture packs set terms for their goods. This builds on `game-data-codegen` M3 (merged). It is a generator change, so it is not part of `tier-needs-data`.
- **CityCore**: new `Command` cases (`marketBuy`, `marketSell`), `World.market` (season counters, decoded as empty when missing), `marketTraded` in `WorldEvent` and the CLI JSON, and `WorldSnapshot.market`. Save format: one optional field, and older saves load with fresh counters.
- **CityUI**: a market section in the inspector for town centers. In-flight work touches the same views: `add-forestry` M3 adds inspector key lines and the tool strip hint; `fix/game-over-banner` (#30) locks tools after game over, and the market buttons must follow the same lock; `add-tvos-port` M2/M3 adds focus sections and remote input to the inspector. Expect merge conflicts in `InspectorView.swift` and `CityUI.swift`, but no spec conflicts: this change adds requirements and does not modify "Inspector callout" or "Tool strip".
- **Determinism**: trades are commands and change state only at tick boundaries, with integer prices. The `DeterminismFixture` issues no player commands, so its output does not change.
- No new build-time tools. No new art.
