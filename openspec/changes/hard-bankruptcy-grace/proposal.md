## Why

Taxes and upkeep are booked every 50 ticks. Hard's bankruptcy grace is 30 ticks, shorter than that interval, so a Hard player whose balance dips below zero right after a collection loses the game before the next tax ever arrives (#72). That is a rule defect, not difficulty: no amount of income can save a dip it never gets to see.

The #72 re-measurement also found that the market keeps a scripted town solvent where it would otherwise go broke, but nothing guards that.

## What Changes

- **BREAKING (balance):** Hard's bankruptcy grace rises from 30 to 50 ticks. No difficulty's grace is shorter than the tax interval. Upkeep and costs are unchanged.
- **BREAKING (balance):** the game ends once the balance has been below zero for more ticks than the grace, not for exactly the grace, so a dip that starts on a collection tick sees the next collection.
- A solvency requirement: a scripted town that trades at its market stays solvent on Normal. The 10-seed, 15-year sweep and a no-market control run with `RIVAL_SWEEP=1` in the weekly `rival-sweep` workflow.

## Capabilities

### New Capabilities
- (none)

### Modified Capabilities
- `difficulty-and-goals`: "Difficulty" sets Hard's grace to 50 ticks.
- `economy`: adds "Early solvency with the market".

## Impact

- **CityCore**: `Difficulty.swift` (grace in tax intervals), `World+Economy.swift` (the bankruptcy check), and `Economy.bankruptcyGraceTicks`, read only by tests, removed. A scripted player bot in the test target.
- **CI**: `.github/workflows/rival-sweep.yml` gains the solvency sweep and its control.
- **Determinism**: the `DeterminismFixture` plays Normal, so its output does not change.
