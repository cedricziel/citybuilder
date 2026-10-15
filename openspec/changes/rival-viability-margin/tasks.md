## 1. Margin above the viability floors

- [x] 1.1 Tests-first: translate the `rival-towns` / Rival build order scenarios "Three farms for every two houses", "Replanting towns keep their huts", "A full town center gets a warehouse" and "The building cap does not stop a first warehouse" into failing swift-testing tests in CityCoreTests; confirm red
- [x] 1.2 Implement to green: the farm ratio (design D1), the hut limit once a forester stands (design D2) and the first warehouse before the threshold rules and at the cap (design D3)
- [x] 1.3 Update rival test fixtures whose stock filled the town center exactly
- [x] 1.4 Run the rival sweep (seeds 0–9, Easy/Normal/Hard, 36,000 ticks, release) and record the year-5 and year-15 numbers in design "Evidence"
- [x] 1.5 Run `DeterminismFixture` twice at each length with `SWIFT_DETERMINISTIC_HASHING=1`, confirm byte-identical output, and regenerate the `game-data-codegen` baseline in its own commit that says why
- [ ] 1.6 Run the `rival-sweep` workflow with `workflow_dispatch` on the branch and link the run in the PR
- [x] 1.7 Refactor under a green bar
- [x] 1.8 Run `SCENARIO_COVERAGE_STRICT=1 make test-scenarios` and confirm no uncovered scenario in `rival-towns` from this change
