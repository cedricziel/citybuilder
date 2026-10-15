## 1. Hard grace and the solvency check

- [x] 1.1 Tests-first: "Hard grace spans a tax interval", "A market-trading town stays solvent on Normal" and "Market-trading towns stay solvent across seeds"; confirm red where the behaviour is missing
- [x] 1.2 Implement to green: Hard's grace of 50 ticks (design D1)
- [x] 1.3 Add the scripted player bot to the test target (design D2), and the sweep step to the `rival-sweep` workflow
- [x] 1.4 Re-measure Hard with and without the market, before and after, and record it in the PR
- [x] 1.5 Confirm the `DeterminismFixture` output is unchanged
- [x] 1.6 Run `SCENARIO_COVERAGE_STRICT=1 make test-scenarios` and confirm no uncovered scenario from this change
