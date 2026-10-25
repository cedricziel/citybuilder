## 0. Design

- [ ] 0.1 Proposal, design and spec deltas; `openspec validate add-orders --strict`
- [x] 0.2 Claude Design canvas: option A approved (chip and side board, parchment banners), on condition that the board layout is specified and never covers the minimap or build rail

## 1. Game data

- [ ] 1.1 Tests-first: the `Order` kind, `orderEvery` on `Age`, validation (unknown good, unknown age, window and size bounds), generated `OrderTemplate` catalog
- [ ] 1.2 `GameDataGen`: model, loader, validator, emitter, JSON schema; regenerate with `make gamedata`
- [ ] 1.3 `orders` pack with the crown and rival templates; `orderEvery` on the four ages

## 2. CityCore: issuing

- [ ] 2.1 Tests-first: the `orders` scenarios for templates, schedule, sizing, board and offer lapse; confirm red
- [ ] 2.2 `OrdersState`, `Order`, `OrderRules`, `Difficulty` knobs, tick step, issuing for the crown and for rivals
- [ ] 2.3 Order events and their cases in `WorldEvent`

## 3. CityCore: accepting and delivering

- [ ] 3.1 Tests-first: accept, decline, abandon, dispatch (plan, all-or-nothing, ETA refusal, immediate leg), shipment walk and arrival
- [ ] 3.2 Commands `acceptOrder`, `declineOrder`, `abandonOrder`, `dispatchOrder`; `orderDispatchPlan`
- [ ] 3.3 Rival delivery through the port trade (`rival-trade` delta); fulfilment, failure, favour
- [ ] 3.4 Favour perks: research discount, rival prices
- [ ] 3.5 `Goal.orders`; `WorldSnapshot` carries the board, the favour and the shipments (as carriers)

## 4. Saves and determinism

- [ ] 4.1 Decode a save without orders; round-trip test; fixture from the previous version
- [ ] 4.2 One orders run in `DeterminismFixture`; regenerate the baseline on purpose, on macOS and Linux

## 5. PlayerBot and sweeps

- [ ] 5.1 `OrdersKit` for the bot (accept what it can fill, send when stocked, ignore rival orders without ships)
- [ ] 5.2 Before and after sweeps: first-hour solvency, rival viability, market control, mid-game pacing; tune template shares and rewards until the bars hold
- [ ] 5.3 Orders in the weekly `rival-sweep` workflow and `SOLVENCY_SWEEP` / `PACING_SWEEP` lines

## 6. UI (after the canvas is approved)

- [ ] 6.1 Tests-first: the `platform-shells` scenarios as failing CityUI tests
- [ ] 6.2 Order board (iOS, macOS, tvOS), favour readout, `OrderBoardLayout` (never overlaps the minimap, rail, dock or tool strip; the inspector coexists or is replaced by size class)
- [ ] 6.3 Notifications and the HUD orders chip; audio binding for the order events
- [ ] 6.4 `design/web`: `OrdersPanel`, the HUD chip and previews; `npm run typecheck` and `npm run build`
- [ ] 6.5 Before and after shots, and the canvas "Built" artboard with the board layout at each size class

## 7. Wrap-up

- [ ] 7.1 `make test-scenarios`, coverage (100% diff in CityCore), lint, format
- [ ] 7.2 PR with the problem, approach, tests, sweep tables, `## Design`, `## Design system` and `Closes #255`
- [ ] 7.3 After merge: republish the design-system components; archive this change
