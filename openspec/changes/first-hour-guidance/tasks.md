## 1. Design and measurement

- [x] 1.1 Put today's HUD and the guide options on a Claude Design canvas; option A plus B's caption picked (design D3)
- [x] 1.2 `PlayerBot.firstSteps` and `guideSteps` (design D4)
- [x] 1.3 Measure the step orders on Hard, seeds 0–9, both layouts, for five years; the table is in design D1
- [ ] 1.4 Sweep tests for "Guided Hard start stays solvent and grows" and "Unguided Hard start goes bankrupt" behind `RIVAL_SWEEP=1`

## 2. Guide

- [ ] 2.1 Tests-first: the guide's step, ledger, hide and leave scenarios against `GameSession`; confirm red
- [ ] 2.2 Implement to green: the `FirstStepsGuide` model on `GameSession` (design D1, D2)
- [ ] 2.3 The card view on the game screen, with the compact capsule (design D3)
- [ ] 2.4 Tests-first, then implement: the tool strip warnings
- [ ] 2.5 Tests-first, then implement: the deficit hint's new advice

## 3. Wrap-up

- [ ] 3.1 Run `SCENARIO_COVERAGE_STRICT=1 make test-scenarios` and confirm no uncovered scenario from this change
- [ ] 3.2 `make lint && make format`, `/simplify`, `openspec validate first-hour-guidance --strict`
