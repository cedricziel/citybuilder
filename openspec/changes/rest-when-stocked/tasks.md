## 1. Rest level and the rule

- [ ] 1.1 GameDataGen: optional `restAt` on goods (schema, loader, validator, emitter) with tests; packs set 40 (design D1)
- [ ] 1.2 Tests-first: the "Producers rest while the stores hold plenty" scenarios; confirm red
- [ ] 1.3 Implement `World.isResting(_:)` and skip resting consumers in supply dispatch (design D2)
- [ ] 1.4 After #232 lands: merge main; direct hops skip resting targets through the same predicate, with a test

## 2. Visible and calm

- [ ] 2.1 Tests-first: the resting issue and the calm inspector line; confirm red
- [ ] 2.2 Implement `BuildingIssue.resting(Good)` and the inspector line (design D4)

## 3. Research retune

- [ ] 3.1 Measure pacing with resting; pick the research factor; write the `research` and `culture-content` deltas (design D3)
- [ ] 3.2 Packs: the retuned costs

## 4. Measurement and guards

- [ ] 4.1 Pacing sweep with retention: report 20+ merchants at year 10, held share and Renaissance medians
- [ ] 4.2 First-hour solvency and rival viability sweeps stay green

## 5. Wrap-up

- [ ] 5.1 `SCENARIO_COVERAGE_STRICT=1 make test-scenarios`: no uncovered scenario from this change
- [ ] 5.2 `make lint && make format`, `/simplify`, `openspec validate rest-when-stocked --strict`
