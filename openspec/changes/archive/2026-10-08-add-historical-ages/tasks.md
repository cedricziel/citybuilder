## 1. M1 — Ages in CityCore

- [x] 1.1 Tests-first: translate every scenario in this change's historical-ages, research and buildings-and-construction specs into failing tests in `CityCoreTests`. Confirm red.
- [x] 1.2 Implement to green: `Age`, BC dates, era techs and tech ages, the top-tier gate, advancing and calendar jumps, starting age, obsolescence, the quern house (design D1–D6).

## 2. M2 — Persistence

- [x] 2.1 Tests-first: translate `#### Scenario: v6 save loads in the Medieval age` into a failing test with a v6 fixture. Confirm red.
- [x] 2.2 Implement to green: version 7 and the v6 → v7 migration (D9).

## 3. M3 — Art

- [x] 3.1 Compose `style(culture, age)` in the building kit and draw the 48 age houses and the quern house; register them; run `make sprites-procedural` and `make sprites-verify` (D7).

## 4. M4 — UI and rendering

- [x] 4.1 Tests-first: translate the platform-shells, rendering-2_5d and sprite-style-catalog scenarios into failing tests. Confirm red.
- [x] 4.2 Implement to green: age picker, age banner, palette filtering, research panel era rows, age house lookup (D7, D8).

## 5. M5 — Verification

- [x] 5.1 Runtime check on a dedicated simulator: start in Antiquity (BC date, stone houses, quern house in the palette, no windmill) and in Industrial (brick houses, 1780).
- [x] 5.2 Run lint, format, `make test`, `make test-scenarios` and `openspec validate add-historical-ages --strict`.
