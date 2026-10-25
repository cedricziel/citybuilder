## Why

The HUD shows the balance, the date and a stocks tray with current amounts. Nothing shows a trend. When a producer stops because its output has nowhere to go (per-good storage), the player sees a status icon on that one building, but never that bread production has outrun demand for two seasons. Balance work runs through PlayerBot sweeps that print lines; players have no equivalent. Issue #256.

## What Changes

- **History in the simulation.** `World` keeps a ring of the last 40 seasons of player aggregates, written at each season boundary:
  - per good: made, used (by houses, by production, by construction), sold, bought, the stock at season end, and how often a producer was stopped with that good stuck
  - money: tax, upkeep, trade income and spending, the balance at season end
  - residents per house tier
  - per producer kind: how often its producers were working, waiting for input, stopped because the output has nowhere to go, or blocked for another reason
  - per rival: residents, age and treasury
- **Bounded and deterministic.** The ring holds at most 40 finished seasons plus the one in progress. Every number is an integer, and zero entries are left out. It is part of the world and is saved.
- **Statistics sheet** on iPhone, iPad, Mac and Apple TV, opened from a new HUD menu button (`chart.xyaxis.line`). A segmented control picks Goods, Money, People or Rivals. Goods shows made against used, the store level against its cap and a "stopped: output stuck" strip, per good, and a working/waiting/stuck bar per producer kind. The sheet only reads.
- Design: Claude Design canvas https://claude.ai/artifact/MuHEcsVfyPWQzNmF2evWhi, option A.

## Capabilities

### New Capabilities
- `statistics`: the season history in the simulation and the Statistics sheet.

### Modified Capabilities
- `persistence-save-load`: saves made before the history decode with an empty one, with no version bump.

## Impact

- **CityCore:** new `Statistics.swift` (types) and `World+Statistics.swift` (recording); `World` gains one stored property; the tick calls one new system last; `WorldSnapshot` carries the history. One line in `consumeIfDue` (`World+Population.swift`) reports what houses drew. No production, carrier, storage or economy logic changes.
- **CityUI:** a view model that turns the history into chart series, the sheet, the HUD button and the Apple TV entry.
- **CityPersistence:** no format change; the new key is optional on load.
- **design/web:** a `StatisticsPanel` component, the `chart.xyaxis.line` icon, a preview.
- **Order:** the "stopped" counts classify a producer the way the production system stalls it today, and take the stuck good from the same rule `per-good-storage` uses for `BuildingIssue.outputStuck`; after that change merges, the classification is checked against it.
