## Why

A house advances a tier once it is full and every need of the next tier is "in reach". Today that only means some buffer on its road network holds at least one unit of the good. When tools come back into stock, every full citizen house on the network sees them at once. They all advance 120 ticks later and draw tools together. One unit in a store can't feed a burst of new merchants, so the tools run out, and the new merchants decline together once their grace has run out.

The handcart probes (#278) measured this on Easy careful single-island, seed 2, in a town with about 150 citizens at capacity:
- In one season its houses drew 74 tools against the usual 24, and tool stock fell from 69 to 24.
- The merchant count swung 31 → 22 → 30 → 23 → 100 → 0 over years 8.75–10.

The decline grace (#274) damped the decline half of that swing, but the advance half is still there. Players see the same flicker: a row of houses turns into merchant houses, and most of them fall back a season later.

## What Changes

- **BREAKING (balance):** a house advances a tier only when, for every need the next tier adds (bread, tools, cloth and the luxury for merchants; planks for citizens), the buffers in its reach hold enough of the good for two of its draws at its current residents. One unit in reach is no longer enough for those. A need the house already has, such as food, keeps today's rule: advancing adds no new demand for it, and a town's food often sits near zero in store because farms deliver it as it is eaten.
- Houses are visited in entity order every tick. A house that advances claims those two draws of each added need from its road network for the rest of that tick. A later house on the same network sees the stock minus the claims, so a burst can't all advance on the same units. Claims last one tick and move nothing.
- A house that can't advance this way restarts its 120-tick advancement count, exactly as it does today when a need is out of reach.
- What makes a need met, consumption, growth, the decline grace and decline are unchanged. Rival houses follow the same rule.

## Capabilities

### New Capabilities
<!-- None. -->

### Modified Capabilities
- `population-and-needs`: advancing a tier needs stock in reach for two draws of each binding need, net of what houses that advanced earlier in the same tick claimed.

## Impact

- **Code:** `World+Population.swift` (the advancement check and the per-tick claims) and `Systems.swift` (stock in reach on a road network).
- **Saves:** none. Claims live for one tick and are never saved.
- **Determinism:** advancement timing changes, so the `DeterminismFixture` baseline moves. It is regenerated in its own commit.
- **Balance:** measured with the pacing, solvency and rival sweeps against current main. Retention is judged on held share of years 8–10 and on mean merchants over years 8–10.
- **Dependencies:** none new.
