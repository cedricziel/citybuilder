## 1. Research ×10 and difficulty scaling

- [x] 1.1 Tests-first: "Research cost scales with difficulty" and the new tech-tree costs; confirm red
- [x] 1.2 Packs: the ×10 costs (design D1); regenerate; `Difficulty.researchCostPercent` and `World.researchCost(of:)` (design D2)
- [x] 1.3 Research panel shows the scaled cost

## 2. Sustained gate

- [x] 2.1 Built `eraGate.heldSeasons` and the held check; measured with section 1; dropped by the keep-or-drop rule and removed (design D3)

## 3. Measurement and keep-or-drop

- [x] 3.1 Pacing sweep: A alone and A + B; apply the keep-or-drop rule (design D3)
- [x] 3.2 First-hour sweep and rival viability sweep stay green
- [x] 3.3 Determinism: no stored baseline; CI compares macOS and Linux runs of the same code

## 4. Wrap-up

- [x] 4.1 `SCENARIO_COVERAGE_STRICT=1 make test-scenarios`: no uncovered scenario from this change
- [x] 4.2 `make lint && make format`, `/simplify`, `openspec validate slow-the-mid-game --strict`
