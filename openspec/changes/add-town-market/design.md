## Context

See proposal.md (Why). Money flows in today through tax, caravans (`culture-signatures`: a caravanserai sells up to 4 or 8 units every 100 ticks at base price) and selling to rivals by ship (`rival-trade`: rivals sell at 125% and buy at 75% of base, in limited offers, archipelago only). Money flows out through building costs, upkeep, gallery commissions and buying from rivals. Every good has a `basePrice` in its pack (`core.yaml`, culture packs). Rival prices are derived from it in Swift (`RivalMarket.swift`).

`add-forestry` (spec merged, M1 in review as #33) makes wood renewable and the lumberjack hut free of materials. It does not help with planks or food shortages, or with a surplus that has no use.

### Balance evidence

I checked the numbers with a throwaway harness (not committed) built on the one behind `add-forestry`. A scripted player with the rival AI's threshold rules works through a build order up to tools on the seed-0 single island. Each run is 9,600 ticks (4 in-game years). The market was emulated with the rules below: 150%/50% prices, 10/20 seasonal limits, and wood, planks and food buyable. The forester was emulated as one per hut, planting every 40 ticks (80 in winter), plus 2 free wood whenever a hut was needed. The player's market policy was to keep 2 wood for a new hut, keep food at 4 (or 1 for "emergency only"), and sell stock above 30 of a good when the balance fell below $150.

| Run | Spring 1202 | Spring 1204 | First 20 citizens | Market use over 4 years |
|---|---|---|---|---|
| A — `main` (no forester, no market) | 0 residents, $305 | 0 residents, $113 | never | — |
| B — market only | 10 residents (7 citizens), $931 | 21 residents (0 citizens), $2,642 | Spring 1201 | bought 99 wood and 61 food ($960); buy limit reached 93 times |
| D — forester only | 0 residents, $208 | 0 residents, $16 | never | — |
| C — forester + market, keeps food at 4 | 7 residents, $36 | 27 residents (3 citizens), $411 | Summer 1203 | bought 133 food ($798), sold 47 planks ($188), no wood bought |
| F — forester + market, food only when out | 29 residents (10 citizens), $84 | 70 residents (12 citizens), $3,141 | Summer 1201 | bought 58 food ($348), sold 27 wood ($56), no wood bought |

What the runs show:
- **The market removes the remaining soft-locks.** In D the forester kept wood coming, but the sawmill filled the 40-unit town center with planks. No farm went up, there was no food and no room, and the town sat at 0 residents. In F, the same run with the market, the player bought 22 food in the first year and grew to 70 residents.
- **The market does not replace the forester.** In B, with no forester, the wood limit ran out 93 times. Citizens fell back to peasants once the island's forest was gone, and $2,642 sat idle. With the forester (C, F), the player never bought wood.
- **Overbuying is a money sink, not an exploit.** C's player topped food up to 4 every 30 ticks and spent $798, which kept the balance under $70 for three years and delayed citizens by two years compared to F. Selling surplus earned at most $188 in any run, far below the $3,520 a year cap (D4).

## Goals / Non-Goals

**Goals:**
- Give money a use at every stage of the game, and give the player a way out of a basic-goods shortage on any map.
- Keep production, the forester, rival trade and caravans the better choice. The market is a convenience at a bad price with a small volume.
- No money from nothing: no trade loop and no unbounded income.

**Non-Goals:**
- Dynamic prices, supply and demand, or price history.
- Rivals using the market, or the market moving rival prices.
- A market building, or a delivery that carriers or ships perform. Trades are instant at the town center.
- Different prices or limits by difficulty. These could be added later as pack or difficulty data without changing the rules.

## Decisions

### D1 — The town center is the market

Every operational player town center trades for its island. There is no new building, no art, no research gate and no placement. The market exists from the first tick, so it is the safety valve for an early shortage. Bought goods land in the town center's own stockpile, which is a goods buffer that houses and producers already draw from. Sold goods come out of the island's goods buffers in ascending entity ID order, the same order `consume` uses.

- **Alternative — a market hall building, unlocked by research.** Rejected: it adds placement, art and a tech for no new decision, and a shortage in the first year happens before any research.
- **Alternative — deliveries by carrier from the island edge.** Rejected: it adds a moving part that brings nothing to a 1–10 unit emergency buy, and it would make the market depend on roads.

### D2 — Prices: 150% to buy, 50% to sell

`price = max(1, basePrice × percent / 100)`, rounded down, the same formula as rival prices. The channels rank as follows:

| Channel | Player buys at | Player sells at |
|---|---|---|
| Town market | 150% | 50% |
| Rival port | 125% | 75% |
| Caravanserai | — | 100% |

Every buy price is at least every sell price, including the $1 floors and integer rounding (grain: rival 3, caravan 3, market 1). So no round trip gains money. The market is the worst channel in both directions, so rival trade and caravans keep their reason to exist.

The spreads are Swift constants next to the rival spreads. They are rules about how trade works, not content per good. The base prices they apply to stay in the packs.

- **Alternative — buy 200% / sell 25%.** Rejected: at 200% an emergency plank costs $16, twice the base, which punishes a beginner who used the market as intended. At 25% grain, hops and other $3 goods hit the $1 floor and become flat, and selling stops being worth a tap.

### D3 — What can be traded

Wood, planks and food can be bought. They are the basic building and peasant goods, and the goods behind every soft-lock seen in the playtests. Bread, tools, iron, flour and the culture luxuries cannot be bought, so the citizen and merchant tiers still need their chains. Every good can be sold.

Limits are content: an optional `market: { buy: N, sell: N }` on each `Good` in the packs. `GameDataGen` validates both as non-negative integers and emits `Good.marketTerms`. A pack that adds a good decides whether the market trades it, without Swift edits.

### D4 — Seasonal limits, per player

Per good and per season, the player can buy at most 10 units (each buyable good) and sell at most 20 units (every good). Counts are kept per player across all their town centers, so an archipelago with several town centers gets no extra volume. They reset when the season changes, the same tick `seasonChanged` is emitted.

Why these numbers:
- One lumberjack hut cuts 1 wood per 30 ticks, 80 a year. The market sells at most 40 wood a year, at $6 instead of the hut's one-off $80. Half a hut's output, at $240 a year, is a bridge, not a supply.
- A citizen house eats 1 plank per 100 ticks, 24 a year. The market's 40 planks a year keep fewer than 2 citizen houses supplied.
- Sell income is capped for each good: 20 × 4 seasons × the sell price. Summed over all ten core goods (sell prices 2+4+2+6+1+3+2+2+7+15 = $44) that is $3,520 a year, plus $640 for a culture's two goods. A medium town's tax is many times that, so the market is a side income that needs the chains already built. It is not a money printer.

`World.market` holds `bought` and `sold` as `[Good: Int]` for the current season. It is `Codable` and decoded as empty when missing.

- **Alternative — unlimited volume with falling prices.** Rejected for now: it is more realistic but harder to read, and it needs state for each good that decays over time. The fixed limit shows "10 left" in the UI.
- **Alternative — a limit per town center.** Rejected: on an archipelago it multiplies the volume by the number of islands the player holds.

### D5 — Commands and events

`Command.marketBuy(EntityID, Good, Int)` and `Command.marketSell(EntityID, Good, Int)` are applied in queue order at the tick boundary, like every player command. Partial fills are normal. A command that moves nothing changes nothing and emits nothing; the snapshot's "left" counts tell the UI why. `WorldEvent.marketTraded(good:quantity:total:direction:)` reuses the `TradeDirection` type from rival trade. Game over drops player commands, so no trade happens after it (`fix-early-game-edge-cases`). The market spec states this as well.

### D6 — Snapshot and UI

`WorldSnapshot.market` lists, for each good with a non-zero limit and in catalog order: buy price, sell price, units left to buy and units left to sell this season. The inspector's town center details get a `TownMarketSection` that builds the row strings and button states from the snapshot plus the town center's free space and island stock. It follows the shape of `RivalMarketSection`. Buttons call `GameSession` to enqueue commands, the same way `commission` and `setExport` do.

### Framework-free invariant

The market rules, limits, prices, commands and snapshot field are all in `CityCore`, which keeps using Foundation only. CityUI only formats strings and enqueues commands. `scripts/check-no-apple-ui-imports.sh` stays green.

### Determinism

Trades are commands, so they change state only at tick boundaries, in queue order. Prices and limits are integers. Sell order walks buffers sorted by entity ID, never `Dictionary` order. The season reset is a pure function of `tickCount`. The `DeterminismFixture` issues no player commands, so its output is unchanged. The rival system never reads the market state, so rival behaviour is unchanged too.

## Risks / Trade-offs

- [Early food buying skips the farm] → Food costs $6 against a farm's $60, and 10 a season feeds only a few peasant houses (a house of 4 eats 2 food per 100 ticks, 48 a year). A farm still pays for itself within the first year.
- [The market hides a broken supply chain] → The inspector's building issues and the "left this season" counts stay visible, and the limit runs out fast.
- [A content pack sets huge limits] → The generator only checks that limits are non-negative. Balance review of packs (`gamedata-review` skill) covers the values.
- [Merge conflicts with in-flight UI work] → `add-forestry` M3 (inspector key lines, tool strip hint), #30 (game-over lock of tools) and `add-tvos-port` M2/M3 (focus and remote input) all touch `InspectorView.swift` and `CityUI.swift`. This change adds a new details section and requirement and modifies none of theirs. Land it after #30 and wire the buttons to the same game-over lock.
- [Players never discover the market] → The town center is usually the first thing selected. The section sits in the inspector details. A future onboarding hint could point at it.

## Migration Plan

`World.market` is decoded as empty when missing, so old saves load with fresh limits. New commands in a saved pending queue only exist in new saves. Rollback is a revert. A save with market counts loads in an older build only if that build ignores unknown keys, which `World`'s synthesized `Codable` does.

## Open Questions

- Should Easy get larger limits and Hard smaller ones? This can be added later as difficulty data without changing these requirements' shape, though the scenarios would gain a difficulty.
