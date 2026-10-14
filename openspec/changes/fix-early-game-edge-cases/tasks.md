## 1. M1 — Early-game edge cases

- [x] 1.1 Tests-first: translate the `economy` scenarios "Placement after game over is dropped", "Demolish after game over is dropped" and "Lost game still saves", and the `calendar-and-events` scenario "Rats skip an empty granary", into failing swift-testing tests in CityCoreTests; confirm red
- [x] 1.2 Implement to green: `economy` / Game over stops player commands — `World.tick` drops player commands while `economy.gameOver` is set (design D1–D3)
- [x] 1.3 Implement to green: `calendar-and-events` / History events at the turn of the year — the calendar system skips rats when no operational player goods buffer holds food (design D4, D5)
- [x] 1.4 Run the determinism fixture twice and confirm identical output
- [x] 1.5 Refactor under a green bar
- [x] 1.6 Run `SCENARIO_COVERAGE_STRICT=1 make test-scenarios` and confirm no uncovered scenario in `economy` or `calendar-and-events` from this change

## 2. M2 — Game-over feedback and the rats threshold

- [x] 2.1 Tests-first: translate the `platform-shells` scenarios "Bankruptcy banner stays up", "Build tools stay off after game over", "Game over disarms the armed tool" and "Research is off after game over", and the `calendar-and-events` scenario "Rats skip a single food", into failing swift-testing tests in CityUITests and CityCoreTests; confirm red
- [x] 2.2 Implement to green: `calendar-and-events` / History events at the turn of the year — rats needs at least 2 food in one operational player store (design D8)
- [x] 2.3 Implement to green: `platform-shells` / Game-over banner and tools — the persistent banner in `GameSession.banner` (design D6) and the session gating of tools, tile menu, pending placement and research (design D7)
- [x] 2.4 Disable and dim the build rail, its drawer and the research button while the game is over
- [x] 2.5 Refactor under a green bar
- [x] 2.6 Run `SCENARIO_COVERAGE_STRICT=1 make test-scenarios` and confirm no uncovered scenario in `platform-shells` or `calendar-and-events` from this change
