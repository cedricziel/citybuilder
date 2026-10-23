## 1. M1 — Starter mine site (CityCore)

- [x] 1.1 Tests-first: "Every home island has a mine site" and "Only a missing mine site raises a tile"; confirm red
- [x] 1.2 Implement to green: the mine-site raise after the starter grove (design D1)
- [x] 1.3 Run the fair-start-sites tests and the rival sweep locally, and record the sweep in the PR
- [x] 1.4 Run `DeterminismFixture` twice at each length with `SWIFT_DETERMINISTIC_HASHING=1`, confirm byte-identical output, and regenerate the `game-data-codegen` baseline in its own commit if it changes (it did not)

## 2. M2 — Showing the chain (CityUI)

- [ ] 2.1 Tests-first: "Callout names the next tier's needs" and "Locked drawer tile names its research"; confirm red
- [ ] 2.2 Implement to green: the "Next:" key line (design D2) and the locked tile caption (design D3)
- [ ] 2.3 Run `SCENARIO_COVERAGE_STRICT=1 make test-scenarios` and confirm no uncovered scenario from this change
