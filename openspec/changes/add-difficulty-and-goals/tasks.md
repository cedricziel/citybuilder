## 1. M1 — Core

- [ ] 1.1 Tests-first: translate the difficulty-and-goals scenarios into failing `CityCoreTests`. Confirm red.
- [ ] 1.2 Implement to green: `Difficulty`, economy and event scaling, goals system, scenarios, `newGame` overloads (design D1–D4).

## 2. M2 — Persistence

- [ ] 2.1 Tests-first: translate `#### Scenario: v7 save loads as a Normal sandbox` with a v7 fixture. Confirm red.
- [ ] 2.2 Implement to green: version 8 and the v7 → v8 migration (D6).

## 3. M3 — UI

- [ ] 3.1 Tests-first: translate the platform-shells scenarios into failing `CityUITests`. Confirm red.
- [ ] 3.2 Implement to green: mode and difficulty pickers, scenario list, goals panel, win sheet (D5).

## 4. M4 — Verification

- [ ] 4.1 Runtime check: start First Harvest, see the goals panel and Antiquity; start a Hard sandbox and see $700.
- [ ] 4.2 Run lint, format, `make test`, `make test-scenarios` and `openspec validate add-difficulty-and-goals --strict`.
