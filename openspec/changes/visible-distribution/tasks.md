## 0. Design

- [x] 0.1 Proposal and design with the milestones, sim rules and balance risks; canvas with the porter and handcart looks; the orchestrator signs off
- [x] 0.2 Settle Q1–Q4 with the orchestrator (see design, Resolved Questions)

## 1. Milestone 1: direct chain hops

- [x] 1.1 Spec delta (`warehouses-and-logistics` / Producers deliver to short consumers); tests-first, confirm red
- [x] 1.2 `.deliverToConsumer` mission, destination order (D1), inbound counting in supply
- [x] 1.3 Short-consumer search per tick (D2)
- [x] 1.4 DeterminismFixture gains a grain chain whose producers hop, so CI's macOS-vs-Linux gate covers M1; CityCore 100 % diff coverage; save version 11 (10 went to per-good storage)
- [x] 1.5 PlayerBot sweeps before and after (first-hour solvency, rivals, pacing)

## 2. Milestone 3: handcarts

- [x] 2.1 Spec deltas (`warehouses-and-logistics` / Handcarts; `rendering-2_5d`); tests-first
- [x] 2.2 `Logistics` game-data item with the cart values (D9)
- [x] 2.3 `Carrier.vehicle` and the cart rule (D5); defaults for old saves
- [x] 2.4 Handcart figure in IsoKit from the approved canvas, `.push` pose agreed with the art agent; rendering
- [ ] 2.5 Sweeps, determinism baseline, coverage (fixture haul and coverage done; the sweeps are re-run once the supply output cap and M1 are on main)

## 3. Milestone 2: the market as hub (2a and 2b together)

- [ ] 3.1 Marketplace canvas: look, footprint, cost, research gate; the orchestrator signs off
- [ ] 3.2 Spec deltas (`population-and-needs` modified, market porters added; `buildings-and-construction` marketplace; `rendering-2_5d` porters); tests-first
- [ ] 3.3 Sweeps before (first-hour solvency, rivals, pacing), with designer2
- [ ] 3.4 `hub` game-data block on the town center and the marketplace; house-stock values in `Logistics` (D9)
- [ ] 3.5 Hub preference for house goods and restock hauls (D3)
- [ ] 3.6 House stock, consumption from stock, satisfaction with hysteresis (D4)
- [ ] 3.7 Porter dispatch and missions, including the visible return trip (D4)
- [ ] 3.8 `noMarketInReach` building issue (D10)
- [ ] 3.9 Marketplace building: game data, placement, rendering from its canvas
- [ ] 3.10 Rivals use the same hubs and build marketplaces (D11)
- [ ] 3.11 Save migration: seeded house stock (D6), with a pre-milestone fixture save
- [ ] 3.12 Porter figures in IsoKit from the approved canvas (yoke, with empty-basket return frames), `.yoke` pose agreed with the art agent; `CarrierRendering` picks them
- [ ] 3.13 Sweeps after: first-hour guided sweep at 0/20 bankruptcies, rival sweep green, pacing compared with designer2; determinism baseline; coverage
