## 1. Game data and difficulty

- [ ] 1.1 Tests-first: the `Tier.declineGrace` generator cases and the `Difficulty` scaling scenarios; confirm red
- [ ] 1.2 Implement to green: `declineGrace` on `Tier` (schema, loader, model, validator, emitter, `FORMAT.md`) and `Difficulty.declineGraceIntervals(base:)` (design D3)
- [ ] 1.3 Set the tiers' grace in the core pack and run `make gamedata`

## 2. Decline waits for the grace

- [ ] 2.1 Tests-first: the `population-and-needs` and `persistence-save-load` scenarios; confirm red
- [ ] 2.2 Implement to green: `shortIntervals`, its Codable, the consumption and decline rules (design D1, D2, D5)
- [ ] 2.3 Update the tests that expected a decline after one short interval

## 3. Warning

- [ ] 3.1 Tests-first: the `rendering-2_5d` and `platform-shells` scenarios; confirm red
- [ ] 3.2 Implement to green: `BuildingIssue.runningShort`, the status icon mapping, the inspector's problem text and Details line (design D4)

## 4. Sweeps and wrap-up

- [ ] 4.1 Regenerate the `DeterminismFixture` baseline in its own commit that says why, checked on macOS and Linux (design D6)
- [ ] 4.2 Run the pacing sweep with `PACING_RETENTION=1`, plus solvency, the no-market control and the rival sweep, on `main` and with each candidate N; pick N per tier (design "Evidence")
- [ ] 4.3 `SCENARIO_COVERAGE_STRICT=1 make test-scenarios`: no uncovered scenario from this change
- [ ] 4.4 `make lint && make format`, `/simplify`, `openspec validate decline-grace --strict`
