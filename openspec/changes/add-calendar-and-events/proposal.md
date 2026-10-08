## Why

The game direction drifts between ages through three forces: population tiers create demand, research unlocks supply, and calendar years bring events. The first two exist. Time is still only a tick counter, so the city has no seasons, no sense of years passing and nothing that happens *to* it. This change adds the time side of the drift and gives later changes (ages, signature mechanics, difficulty) a calendar to hang on.

## What Changes

- **Calendar:** the world has a date made of a year and a season. A season lasts 600 ticks (one minute at 10 Hz), so a year takes four minutes. New games start in spring 1200. The date is derived from the tick count and a stored start year, so it can't drift.
- **Seasons affect farming:** in winter, farms and grain farms work at half speed. Other buildings are unaffected.
- **History events:** at the start of each year after the first, the city may get one event, drawn deterministically from the world seed and the year. Events in this change:
  - **Bountiful harvest:** 8 food arrives in the town's stores.
  - **Trade caravan:** +$150.
  - **Travelling scholar:** +20 knowledge.
  - **Rats in the granary:** half the food in every store is lost.
- **World events:** `seasonChanged` and `historyEvent` join the tick event stream.
- **HUD:** shows the date ("Spring 1200") and a banner when a history event fires.
- **Seasonal look:** grass and forest tiles switch to autumn colours and to snow in winter.
- **Saves:** a v4 → v5 migration adds the calendar to existing saves.

## Capabilities

### New Capabilities

- `calendar-and-events`: the date, seasons, seasonal farming and history events.

### Modified Capabilities

- `persistence-save-load`: the v4 → v5 migration.
- `platform-shells`: the HUD date and the event banner.
- `rendering-2_5d`: seasonal terrain sprites.

## Impact

- **CityCore:** `Season`, `GameDate`, `CalendarState` on `World`, `HistoryEvent`, a calendar system, new `WorldEvent` cases, the winter rule in production, the date on `WorldSnapshot`.
- **CityPersistence:** save version 5 and its migration.
- **CityUI:** date label, event banner.
- **CityRender2D:** seasonal terrain sprites.
- **Art:** autumn and winter grass and forest sprites.
