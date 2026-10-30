## Why

A house advances a tier once it is full and every need the next tier adds is in stock at the hub serving it. Any unit counts. When tools come back into a hub, every full citizen house that hub serves sees them at once. They all advance 120 ticks later and draw tools together. One unit can't feed a burst of new merchants, so the tools run out, and the new merchants decline together once their grace has run out.

The handcart probes (#278) measured this on Easy careful single-island, seed 2, in a town with about 150 citizens at capacity:
- In one season its houses drew 74 tools against the usual 24, and tool stock fell from 69 to 24.
- The merchant count swung 31 → 22 → 30 → 23 → 100 → 0 over years 8.75–10.

The decline grace (#274) damped the decline half of that swing, but the advance half is still there. Players see the same flicker: a row of houses turns into merchant houses, and most of them fall back a season later.

## What Changes

- **BREAKING (balance):** a house advances a tier only when, for every need the next tier adds (bread, tools, cloth and the luxury for merchants; planks for citizens), its serving hub holds two of its draws at its current residents. One unit is no longer enough for those. A need the house already eats keeps the market-hub rule: it counts while it is met.
- Houses are visited in entity order every tick. A house that advances claims those two draws of each added need at its serving hub for the rest of that tick. A later house served by the same hub sees the stock minus the claims, so a burst can't all advance on the same units. Claims last one tick and move nothing.
- A house that can't advance this way restarts its 120-tick advancement count, exactly as it does today when the hub lacks a need.
- What makes a need met, consumption, porters, growth, the decline grace and decline are unchanged. Rival houses follow the same rule.

## Capabilities

### New Capabilities
<!-- None. -->

### Modified Capabilities
- `population-and-needs`: advancing a tier needs two draws of each added need at the serving hub, net of what houses that advanced earlier in the same tick claimed there. This fills the "how much stock advancing takes" slot that the market hubs left in "Houses advance and decline between tiers" (visible-distribution).

## Impact

- **Code:** `World+Population.swift`: the advancement check, the per-tick claims keyed by hub, and `advancementStock`, the one place the advancing stock is read.
- **Saves:** none. Claims live for one tick and are never saved.
- **Determinism:** advancement timing changes, so the `DeterminismFixture` baseline moves. It is regenerated in its own commit.
- **Balance:** measured with the pacing, solvency and rival sweeps against the market-hub baseline. Retention is judged on held share of years 8–10 and on mean merchants over years 8–10.
- **Dependencies:** the market hubs (visible-distribution M2).
