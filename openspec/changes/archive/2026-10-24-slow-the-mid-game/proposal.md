## Why

The #186 pacing sweep shows the mid-game is short and bunched. With a consumer-first scripted player and the market, Normal reaches the Renaissance in a median of 3.6 years, and the first merchant, 20 merchants and the Renaissance land within weeks of each other.

The owner's target is about 6–8 years to the Renaissance on Normal, with distinct beats between them. Easy should stay clearly faster and Hard slower.

Research is no brake today. One library yields about 240 knowledge a year, while the medieval techs cost 210 together and the printing press 250.

## What Changes

- **Medieval research ×10:** milling 400, mining 400, metallurgy 800, cultivation 500, and the printing press 2,500. This is pack data. Measured alone, Normal reaches the Renaissance in a median of 6.5 years (Easy 5.8, Hard 7.3), with as many successes as today.
- **Research cost scales with difficulty:** Easy pays 80% of a tech's cost and Hard 120%, so Easy is clearly faster.
- All tunables stay in data or in `Difficulty`, so a retune after the walkers' visible-distribution milestone is a data change.

A sustained-merchants gate (20 merchants held for a season before the printing press) was built and measured, then dropped. With it, the Renaissance came in 0 of 20 Normal starts: today's towns never hold 20 merchants for more than about 240 ticks, because tools run short (#223). It can return once #223 steadies the merchants.

Out of scope:
- The wool → cloth merchant chain, which is its own change and built after this one.
- Seafaring's cost, which is unmeasured and gates ports.
- Steam power and electricity.

## Capabilities

### New Capabilities
- (none)

### Modified Capabilities
- `research`: new tech costs; adds "Research cost scales with difficulty".
- `culture-content`: Cultivation costs 500.

## Impact

- **Game data:** `core.yaml` and `ages.yaml` costs.
- **CityCore:** research progress compares against the difficulty-scaled cost (`World.researchCost(of:)`).
- **CityUI:** the research panel shows the scaled cost.
- **Determinism:** the fixture compares macOS and Linux runs of the same code, so there is no stored baseline to move.
- **Sweeps:** the first-hour sweep and the rival viability sweep stay green; neither the guided bot nor rivals research.
