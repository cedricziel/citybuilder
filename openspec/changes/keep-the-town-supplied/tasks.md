## 1. Measure the first ideas

- [x] 1.1 Wood reserve for the charcoal burner: measured, dropped (design D1)
- [x] 1.2 Store-full hint: measured, dropped (design D1)

## 2. Idle-good hint

- [ ] 2.1 Tests-first: `World.idleGoods(of:)` (design D2)
- [ ] 2.2 Tests-first: the "Idle-good hint" scenarios against `GameSession`; confirm red
- [ ] 2.3 Implement to green (design D2, D3)

## 3. Measurement

- [ ] 3.1 `naiveFollowingHints` follows idle goods; the sweep records the hints of every game (design D4)
- [ ] 3.2 Re-run the market arms; report naive misses, bankruptcies, per-layout totals, and the careful order's false positives

## 4. Wrap-up

- [ ] 4.1 `SCENARIO_COVERAGE_STRICT=1 make test-scenarios`: no uncovered scenario from this change
- [ ] 4.2 `make lint && make format`, `/simplify`, `openspec validate keep-the-town-supplied --strict`
