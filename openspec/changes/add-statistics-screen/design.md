## Context

- `World.tick()` returns the events of the tick. Production, trade, tax and upkeep all emit events, and a system that runs last can read them without touching the systems that emit them.
- A season is 600 ticks (`CalendarState.ticksPerSeason`). `runCalendarSystem` resets the market ledger on the boundary whether or not the calendar is active, so seasons exist in every world.
- The save is `World` encoded as JSON. `MarketLedger` already shows how to add a field without a version bump: a `KeyedDecodingContainer` overload that falls back to the empty value.
- `per-good-storage` (another agent, `feat/per-good-storage-main`) replaces `BuildingIssue.storageFull` with `.outputStuck(Good)`, removes the rest rule, and does not change `runProductionSystem`.

## Decisions

### D1. One record per finished season, a ring of 40

`StatisticsHistory` holds `seasons: [SeasonStatistics]` (oldest first, at most `capacity` = 40) and `current: SeasonStatistics`, the season in progress. At a season boundary the system finalizes `current` (stock, residents, balance, rivals), appends it, drops the oldest beyond 40 and starts a fresh `current`. `current` is saved too, so a save and load in mid-season loses nothing and the replay stays identical.

`SeasonStatistics.season` is the absolute season number (`tick / 600`) of the season it covers, so the sheet labels the axis from the calendar and a gap never shifts the labels.

### D2. Sources: events first, one hook, one sample

The system runs last in `tick()` and reads the events:

| Number | Source |
|---|---|
| made | `productionCycleCompleted` of a player producer: the recipe's outputs |
| used by production | the same event: the recipe's inputs |
| used by construction | `constructionCompleted` of a player building: its material cost |
| sold / bought | `marketTraded`, `tradeCompleted`, `caravanSold` |
| tax / upkeep | `taxesCollected`, `upkeepPaid` |
| trade income / spending | the totals of the three trade events above |
| fuel burned | read from state: a fuelled player building on its burn tick |
| used by houses | one line in `consumeIfDue` that reports what `consume` actually drew |
| stock, residents, balance, rivals | read at the boundary |
| producer activity | sampled every 10 ticks (see D3) |

Houses are the one number events cannot give: how much a house drew when the buffers held less than it wanted. Everything else needs no change to the systems that produce it, so `per-good-storage` and the wool chain merge without conflict.

Construction is booked when the building completes. A site demolished before then books nothing.

### D3. Producer activity is sampled

Every 10 ticks (one sample per sim-second, 60 per season) each operational player producer is classified once:

- **working**: its production is not stalled
- **waiting**: stalled, and a recipe input is missing
- **stuck**: stalled, all inputs present, and the cycle's output does not fit its own stockpile, because the output has nowhere to go
- **blocked**: stalled for another reason (no trees in reach)

Counts are per producer kind, so the share of time is `count / (sum of the four)`. A stuck sample also adds one to the stuck good, which is the output the producer holds most of (first in catalog order on a tie), the rule `per-good-storage` D3 uses for `.outputStuck`. That is the per-good "stopped" band.

Sampling costs one pass over producers every 10th tick, and reads no state it would have to update.

### D4. Bounded size

Maps are sparse: a good or kind with all zeros is absent. One season holds at most `goods × 8 + kinds × 4 + tiers + rivals × 2 + 8` integers; with 18 goods, 20 producer kinds, 3 tiers and 3 rivals that is under 300, and 41 seasons are under 12,000 integers, about 100 KB of JSON in the worst case and a few KB in a young game. The ring never grows past 41 records.

### D5. Saved without a version bump

`World.statistics` decodes through the same fallback as `market`: a missing key is an empty history. A new key that older saves lack needs no migration, and it avoids a version number that `per-good-storage` and the hops change are also claiming.

### D6. The snapshot carries the history

`WorldSnapshot.statistics` is the world's value. The ring is a value type with copy-on-write storage, so taking a snapshot every frame copies nothing until the next season boundary writes.

### D7. The sheet

Option A of the canvas. `StatisticsViewModel` turns a history into chart series: no SwiftUI, so it is tested headless. The sheet is SwiftUI with Swift Charts (iOS 18, macOS 15, tvOS 18). On a regular width Goods is master-detail; on a compact width the list pushes the detail. On Apple TV the list takes focus and the tabs sit above it. A good with a stopped producer shows an "N stopped" pill and the strip under its chart. Both are driven by the history's stuck counts, which come from `.outputStuck`'s rule (D3).

### D8. What the sheet does not do

No commands. The sheet pauses nothing. "Goal readouts reuse it" (issue item 3) is left to the campaign change that adds those goals.

## Risks / Trade-offs

- **Classification can drift from the status icons.** D3 repeats the stall rule in `Systems.swift` and the stuck-good rule of `per-good-storage`. A test pins both against `buildingIssues()` once that change lands.
- **Construction is booked late.** A long build shows its wood in the season it finished.
- **Rivals show residents and age only**, not their goods.

## Migration Plan

None. Old saves load with an empty history and start recording at the next tick.
