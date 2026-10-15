## Why

Taxes and upkeep are booked every 50 ticks. Hard's bankruptcy grace is 30 ticks, shorter than that interval, so a Hard player whose balance dips below zero right after a collection loses the game before the next tax ever arrives (#72). That is a rule defect, not difficulty: no amount of income can save a dip it never gets to see.

The #72 re-measurement also found that the market keeps a scripted town solvent where it would otherwise go broke, but nothing guards that.

## What Changes

- **BREAKING (balance):** Hard's bankruptcy grace rises from 30 to 50 ticks. No difficulty's grace is shorter than the tax interval. Upkeep and costs are unchanged.
- A solvency requirement: a town built by the rival AI's rules that trades at its market stays solvent on Normal. A short check runs in every CI build; the 10-seed, 15-year sweep runs with `RIVAL_SWEEP=1` in the weekly `rival-sweep` workflow.

## Capabilities

### New Capabilities
- (none)

### Modified Capabilities
- `difficulty-and-goals`: "Difficulty" sets Hard's grace to 50 ticks.
- `economy`: adds "Early solvency with the market".

## Impact

- **CityCore**: `Difficulty.swift` (one value). A scripted player bot in the test target.
- **CI**: the default suite gains a short solvency test; `.github/workflows/rival-sweep.yml` gains the long sweep.
- **Determinism**: the `DeterminismFixture` plays Normal, so its output does not change.
