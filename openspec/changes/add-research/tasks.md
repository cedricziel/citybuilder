## 1. M1 — Research in CityCore

- [ ] 1.1 Tests-first: translate every scenario in this change's research and buildings-and-construction specs into failing tests in `CityCoreTests`. Confirm red.
- [ ] 1.2 Implement to green: `Tech`, `ResearchState`, research system, `.chooseResearch`, tech lock, library (design D1–D4).
- [ ] 1.3 Refactor under a green bar.

## 2. M2 — Persistence

- [ ] 2.1 Tests-first: translate `#### Scenario: v3 save loads with all techs researched` into a failing `CityPersistenceTests` test with a v3 fixture. Confirm red.
- [ ] 2.2 Implement to green: version 4 and the v3 → v4 migration (D5).

## 3. M3 — UI and art

- [ ] 3.1 Tests-first: translate `#### Scenario: Research panel lists tech states` and `#### Scenario: Locked placement message` into failing `CityUITests` tests. Confirm red.
- [ ] 3.2 Implement to green: research panel view model and sheet, HUD button, locked palette entries, rejection text.
- [ ] 3.3 Draw the library procedurally; run `make sprites-procedural` and `make sprites-verify`.

## 4. M4 — Verification

- [ ] 4.1 Runtime check on a dedicated simulator: a new game shows Mine locked; choosing Mining in the panel and waiting with a library unlocks it.
- [ ] 4.2 Run lint, format, `make test-scenarios` and `openspec validate add-research --strict`.
