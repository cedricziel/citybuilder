## 1. M1 — Culture in CityCore

- [x] 1.1 Tests-first: translate every scenario in this change's cultures spec into failing tests in `CityCoreTests`. Confirm red.
- [x] 1.2 Implement to green: `Culture`, `World.culture`, `newGame(layout:seed:culture:)`, tier names, snapshot culture (design D1, D2).

## 2. M2 — Persistence

- [ ] 2.1 Tests-first: translate `#### Scenario: v5 save loads as Northern European` into a failing test with a v5 fixture. Confirm red.
- [ ] 2.2 Implement to green: version 6 and the v5 → v6 migration (D6).

## 3. M3 — Art

- [ ] 3.1 Add the `Style` table and the dome, parapet and stacked-roof primitives; confirm Northern European sprites are byte-identical (D4).
- [ ] 3.2 Draw the 18 culture variants, register them in the catalog, run `make sprites-procedural` and `make sprites-verify` (D5).

## 4. M4 — UI and rendering

- [ ] 4.1 Tests-first: translate the platform-shells, rendering-2_5d and sprite-style-catalog scenarios into failing tests. Confirm red.
- [ ] 4.2 Implement to green: culture picker, inspector tier names, culture-aware texture lookup (D3).

## 5. M5 — Verification

- [ ] 5.1 Runtime check on a dedicated simulator: start an East Asian and a Middle Eastern game and see their town centers.
- [ ] 5.2 Run lint, format, `make test`, `make test-scenarios` and `openspec validate add-cultures --strict`.
