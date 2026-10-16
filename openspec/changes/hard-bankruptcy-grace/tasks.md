## 1. Hard grace and the solvency check

- [x] 1.1 Tests-first: "Hard grace spans a tax interval" and "Market-trading towns stay solvent across seeds"; confirm red where the behaviour is missing
- [x] 1.2 Implement to green: Hard's grace of 50 ticks (design D1)
- [x] 1.3 Add the scripted player bot to the test target (design D2), and the sweep step to the `rival-sweep` workflow
- [x] 1.4 Re-measure Hard with and without the market, before and after, and record it in the PR
- [x] 1.5 Confirm the `DeterminismFixture` output is unchanged
- [x] 1.6 Run `SCENARIO_COVERAGE_STRICT=1 make test-scenarios` and confirm no uncovered scenario from this change

## 2. Review fixes (#150)

- [x] 2.1 Tests-first: "A dip on a collection tick sees the next collection"; confirm red
- [x] 2.2 Implement to green: end the game once the deficit lasts more ticks than the grace (design D1); move the tests that pinned the old boundary and drop the test-only `Economy.bankruptcyGraceTicks`
- [x] 2.3 Move the bot checks to the sweep with a no-market control, "Without the market the same towns go bankrupt" (design D2)
- [x] 2.4 Re-measure Hard and Normal locally, with and without the market, and record it in design "Evidence"
