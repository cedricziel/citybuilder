## 1. Game data

- [x] 1.1 Tests-first: translate the `goods-and-production`, `population-and-needs` and `research` scenarios into failing swift-testing tests in CityCoreTests; confirm red
- [x] 1.2 Implement to green: the goods, buildings and `weaving` tech in the core pack, then `make gamedata` (design D1–D3)
- [x] 1.3 Update the tests whose merchant fixtures lack cloth
- [ ] 1.4 Regenerate the `DeterminismFixture` baseline in its own commit that says why (design D5), checked on macOS and Linux

## 2. Art wiring

- [x] 2.1 Wire the sprites, the goods icons, the build drawer entries and the floating status icons
- [x] 2.2 Update `design/web` to match: the building sprites, the goods icons, the drawer and the research panel

## 3. PlayerBot and sweeps

- [x] 3.1 Tests-first: the bot's demand rules (design D4)
- [x] 3.2 Implement to green: demand-based provisioning for the wool chain
- [x] 3.3 Run the pacing, solvency, rival and no-market sweeps before and after; record design "Evidence"
- [ ] 3.4 After per-good storage merges, merge `main` in and re-run the sweeps

## 4. Wrap-up

- [ ] 4.1 `SCENARIO_COVERAGE_STRICT=1 make test-scenarios`: no uncovered scenario from this change
- [ ] 4.2 `make lint && make format`, `/simplify`, `openspec validate add-wool-cloth-chain --strict`
