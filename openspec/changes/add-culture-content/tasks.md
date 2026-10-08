## 1. M1 — Core

- [x] 1.1 Tests-first: translate every scenario in the culture-content, population-and-needs, goods-and-production and buildings-and-construction specs into failing `CityCoreTests`. Confirm red.
- [x] 1.2 Implement to green: goods, buildings, recipes, culture rule, Cultivation, needs by culture, satisfaction storage with the tolerant decoder (design D1–D4).

## 2. M2 — Art

- [ ] 2.1 Draw the eight buildings and eight icons; register; `make sprites-procedural`, `make sprites-verify` (D6).

## 3. M3 — UI

- [ ] 3.1 Tests-first: translate the platform-shells and sprite-style-catalog scenarios. Confirm red.
- [ ] 3.2 Implement to green: palette filter, inspector needs, research panel listing (D4, D5).

## 4. M4 — Verification

- [ ] 4.1 Runtime check: a Mediterranean game shows vineyard and winery after Cultivation, and a winery produces wine.
- [ ] 4.2 Run lint, format, `make test`, `make test-scenarios` and `openspec validate add-culture-content --strict`.
