## 1. Design and measurement

- [ ] 1.1 Put today's HUD and the guide options on a Claude Design canvas; get a pick before UI work (design D3)
- [ ] 1.2 `PlayerBot.followsFirstSteps`: houses first until 3, then the net check (design D4)
- [ ] 1.3 Measure the four variants on Hard, seeds 0–9, both layouts, for year 1; record the table in the PR
- [ ] 1.4 Sweep tests for "Guided Hard start stays solvent" and "Unguided Hard start goes bankrupt" behind `RIVAL_SWEEP=1`

## 2. Guide

- [ ] 2.1 Tests-first: the guide's step, ledger, hide and leave scenarios against `GameSession`; confirm red
- [ ] 2.2 Implement to green: the guide's model in `GameSession` (design D1, D2)
- [ ] 2.3 Implement the guide view in the layout picked on the canvas, with a compact iPhone form
- [ ] 2.4 Tests-first, then implement: the tool strip caption for buildings that pay no tax

## 3. Wrap-up

- [ ] 3.1 Run `SCENARIO_COVERAGE_STRICT=1 make test-scenarios` and confirm no uncovered scenario from this change
- [ ] 3.2 `make lint && make format`, `/simplify`, `openspec validate first-hour-guidance --strict`
