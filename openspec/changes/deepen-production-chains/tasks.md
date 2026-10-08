## 1. M1 — Goods, recipes and buildings

- [x] 1.1 Tests-first: translate every scenario in this change's goods-and-production, buildings-and-construction and population-and-needs specs into failing tests in `CityCoreTests`. Confirm red.
- [x] 1.2 Implement to green: goods, building kinds, specs and recipes; bakery input becomes flour (design D1).
- [x] 1.3 Implement to green: terrain requirement and `needsTerrain` rejection (D2).
- [x] 1.4 Implement to green: merchants need and consume tools (D3, D4).
- [x] 1.5 Refactor under a green bar.

## 2. M2 — UI and art

- [x] 2.1 Tests-first then green: translate `#### Scenario: Mountain requirement message` into a `CityUITests` test; add palette labels and animation entries.
- [x] 2.2 Draw the six buildings and six icons procedurally; run `make sprites-procedural` and `make sprites-verify`.

## 3. M3 — Verification

- [x] 3.1 Runtime check on a dedicated simulator: a mine on the mountainside is accepted and one on grass is rejected with "Needs mountain ground"; the new buildings render in the register.
- [x] 3.2 Run lint, format, `make test-scenarios` and `openspec validate deepen-production-chains --strict`.
