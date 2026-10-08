## Context

See proposal.md (Why). `World` is a `Codable` snapshot advanced by `tick()` at 10 Hz; systems run in a fixed order and emit transient `WorldEvent`s. New fields reach old saves through numbered migrations (current version 4). Test fixtures start permissive (every tech researched, unlimited materials); `newGame` turns on the real rules.

## Decisions

### D1 — The date is derived, not stored

`CalendarState { startYear: Int, isActive: Bool }` lives on `World`. `World.date` computes `GameDate(year:season:)` from `tickCount`: `season = (tick / 600) % 4` in the order spring, summer, autumn, winter; `year = startYear + tick / 2400`. Storing only the start year means the date can never disagree with the tick count.

- **Alternative — a stored day counter.** Rejected: a second clock that must stay in step with `tickCount` for no gain.

### D2 — `isActive` gates gameplay effects

Seasonal farming and history events run only while `calendar.isActive`. The default `World` has it off, so existing long-running scenario tests keep their meaning; `newGame` and the save migration turn it on. The date is still computed when inactive.

### D3 — Winter halves crop speed

In `runProductionSystem`, a farm or grain farm in winter advances its cycle only on even ticks. It is not stalled, so no stall events fire and the stall badge stays off.

### D4 — History events use a per-year RNG

On the tick that starts a year (tick > 0 and `tick % 2400 == 0`) with the calendar active, a calendar system seeds `DeterministicRNG(seed: seed &+ year &* 0x9E37_79B9_7F4A_7C15)`. The first draw decides whether an event fires (even draw: yes); the second picks one from `HistoryEvent.allCases`. The world's own `rng` is untouched, so other systems' random sequences don't shift.

Effects apply immediately:

| Event | Effect |
|---|---|
| `bountifulHarvest` | deposit up to 8 food into the lowest-ID operational goods buffer, capped by its free space |
| `tradeCaravan` | +$150 |
| `travellingScholar` | +20 knowledge |
| `ratsInTheGranary` | every operational goods buffer loses half its food, rounded down |

- **Alternative — events with durations (a harsh winter that lasts a season).** Deferred: needs active-effect state and UI. The catalog is an enum, so later changes can add those.

### D5 — Events in the tick stream

`WorldEvent.seasonChanged(Season)` fires on each season boundary after tick 0, and `WorldEvent.historyEvent(HistoryEvent)` fires when an event applies. The calendar system runs after the research system, so knowledge from a scholar lands in the same tick.

### D6 — Snapshot and UI

`WorldSnapshot` gains `date: GameDate` (defaulted in the public init so existing call sites compile). The HUD shows `"\(season) \(year)"`. `GameSession.step()` keeps the latest `historyEvent` with the tick it fired; the HUD shows a banner with the event's title and line of text for 60 ticks.

### D7 — Seasonal tint in the scene

`IsoWorldScene` remembers the season it last applied. When the snapshot's season changes, it sets `color`/`colorBlendFactor` on every present grass and forest node; nodes added later get the current tint. Autumn uses a warm orange at 0.25, winter a pale blue-white at 0.45, spring and summer none. No new textures.

### D8 — Migration v4 → v5

Adds `calendar { startYear: 1200, isActive: true }`. An old save's date becomes 1200 plus however long it has run. `SaveFile.currentVersion` becomes 5; a v4 fixture joins the migration fixtures.

## Determinism

Integer tick arithmetic for the date; the event RNG depends only on seed and year; buffers are visited in entity-ID order for harvest and rats.

## Risks / Trade-offs

- **[Risk] Winter food shortfalls push houses down a tier** → Mitigation: half speed, not a stop; the town's stores buffer a season.
- **[Risk] Rats feel unfair early** → Mitigation: no event in the first year; three of the four events help.
