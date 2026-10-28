## 0. Design

- [x] 0.1 Proposal, design and spec deltas; `openspec validate add-orders --strict`
- [x] 0.2 Claude Design canvas: option A approved (chip and side board, parchment banners), on condition that the board layout is specified and never covers the minimap or build rail

## 1. Game data

- [x] 1.1 Tests-first: the `Order` kind, `orderEvery` on `Age`, validation (unknown good, unknown age, window and size bounds), generated `OrderTemplate` catalog
- [x] 1.2 `GameDataGen`: model, loader, validator, emitter, JSON schema; regenerate with `make gamedata`
- [x] 1.3 `orders` pack with the crown and rival templates; `orderEvery` on the five ages (Antiquity 4, Medieval 4, Renaissance 3, Industrial 2, Modern 2)

## 2. CityCore: issuing

- [x] 2.1 Tests-first: the `orders` scenarios for templates, schedule, sizing, board and offer lapse; confirm red
- [x] 2.2 `OrdersState`, `Order`, `OrderRules`, `Difficulty` knobs, tick step, issuing for the crown and for rivals
- [x] 2.3 Order events and their cases in `WorldEvent`

## 3. CityCore: accepting and delivering

- [x] 3.1 Tests-first: accept, decline, abandon, dispatch (plan, all-or-nothing, ETA refusal, immediate leg), shipment walk and arrival
- [x] 3.2 Commands `acceptOrder`, `declineOrder`, `abandonOrder`, `dispatchOrder`; `orderDispatch(for:)` (an `OrderDispatch` enum with the unavailable reasons)
- [x] 3.3 Rival delivery through the port trade (`rival-trade` delta); fulfilment, failure, favour
- [x] 3.4 Favour perks: research discount, rival prices
- [x] 3.5 `Goal.orders`; `WorldSnapshot` carries the board, the favour and the shipments (as carriers)

## 4. Saves and determinism

- [x] 4.1 Decode a save without orders; round-trip test; fixture from the previous version
- [ ] 4.2 `DeterminismFixture` output: the empty `orders` key, equal on macOS and Linux; favour keys written as strings

## 5. PlayerBot and sweeps

- [x] 5.1 `OrdersKit` for the bot (accept what it can fill, send when stocked, ignore rival orders without ships)
- [x] 5.2 Before and after sweeps: first-hour solvency, rival viability, market control, mid-game pacing; tune template shares and rewards until the bars hold
- [x] 5.3 Orders in the weekly `rival-sweep` workflow and `SOLVENCY_SWEEP` / `PACING_SWEEP` lines

## 6. UI (after the canvas is approved)

- [x] 6.1 Tests-first: the `platform-shells` scenarios as failing CityUI tests
- [x] 6.2 Order board (iOS, macOS, tvOS), favour readout, `OrderBoardLayout` (never overlaps the minimap, rail, dock or tool strip; the inspector coexists or is replaced by size class)
- [x] 6.3 Notifications and the HUD orders chip; audio binding for the order events
- [x] 6.4 `design/web`: `OrdersBoard`, `OrdersChip`, the HUD chip and previews; `npm run typecheck` and `npm run build`
- [ ] 6.5 Before and after shots in the game, and the canvas "Built" artboard with the board layout at each size class (the "Built" artboard and a SwiftUI render are on the canvas; the in-game window shots are pending)

## 7. Wrap-up

- [ ] 7.1 `make test-scenarios`, coverage (100% diff in CityCore), lint, format
- [ ] 7.2 PR with the problem, approach, tests, sweep tables, `## Design`, `## Design system` and `Closes #255`
- [ ] 7.3 After merge: republish the design-system components; archive this change
