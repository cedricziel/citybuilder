## 1. Rest level and the rule

- [x] 1.1 GameDataGen: optional `restAt` on goods (schema, loader, validator, emitter) with tests; packs set 40 (design D1)
- [x] 1.2 Tests-first: the "Producers rest while the stores hold plenty" scenarios; confirm red
- [x] 1.3 Implement `World.isResting(_:)` and skip resting consumers in supply dispatch (design D2)
- [x] 1.4 Put the rest check in `needsSupply`, which #232 direct hops also ask, with a test

## 2. Visible and calm

- [x] 2.1 Tests-first: the resting issue and the calm inspector line; confirm red
- [x] 2.2 Implement `BuildingIssue.resting(Good)` and the inspector line (design D4)

## 3. Research retune

- [x] 3.1 Measure pacing with resting; pick the research factor; write the `research` and `culture-content` deltas (design D3)
- [x] 3.2 Packs: the retuned costs

## 4. Measurement and guards

- [x] 4.1 Pacing sweep with retention: report 20+ merchants at year 10, held share and Renaissance medians
- [x] 4.2 First-hour solvency and rival viability sweeps stay green

## 5. Wrap-up

- [x] 5.1 `SCENARIO_COVERAGE_STRICT=1 make test-scenarios`: no uncovered scenario from this change
- [x] 5.2 `make lint && make format`, `/simplify`, `openspec validate rest-when-stocked --strict`
