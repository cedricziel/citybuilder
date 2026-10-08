## 1. M1 — Calendar in CityCore

- [x] 1.1 Tests-first: translate every scenario in this change's calendar-and-events spec into failing tests in `CityCoreTests`. Confirm red.
- [x] 1.2 Implement to green: `Season`, `GameDate`, `CalendarState`, calendar system, winter rule, `HistoryEvent`, world events, snapshot date (design D1–D6).
- [x] 1.3 Refactor under a green bar.

## 2. M2 — Persistence

- [x] 2.1 Tests-first: translate `#### Scenario: v4 save loads with a calendar` into a failing `CityPersistenceTests` test with a v4 fixture. Confirm red.
- [x] 2.2 Implement to green: version 5 and the v4 → v5 migration (D8).

## 3. M3 — UI and rendering

- [x] 3.1 Tests-first: translate `#### Scenario: HUD date text`, `#### Scenario: Banner appears and expires`, `#### Scenario: Winter tints grass` and `#### Scenario: Summer has no tint` into failing tests. Confirm red.
- [x] 3.2 Implement to green: HUD date label, event banner, seasonal terrain tint (D6, D7).
- [ ] 3.3 Replace the tint with seasonal terrain sprites: draw autumn and winter grass and forest procedurally, register them, swap textures by season with fallback (D7, revised after the first runtime check).

## 4. M4 — Verification

- [ ] 4.1 Runtime check on a dedicated simulator: a new game shows "Spring 1200"; after a season the HUD and terrain change, and winter looks snowy.
- [ ] 4.2 Run lint, format, `make test-scenarios` and `openspec validate add-calendar-and-events --strict`.
