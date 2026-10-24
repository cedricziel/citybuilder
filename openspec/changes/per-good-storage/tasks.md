## 1. Per-good storage

- [x] 1.1 GameDataGen: `storagePerGood` building field (schema, loader, validator, emitter), exclusive with `storage`, with tests; packs set 40 / 80 / 80 (design D1)
- [x] 1.2 `Stockpile` per-good mode, `room(for:)`, `World.newStockpile(for:)`; scenario tests
- [x] 1.3 Room per good everywhere a good is known: market reach and purchases, ship unloads, rival port trades, rival purchases, bountiful harvest, island summary capacity

## 2. Backpressure

- [x] 2.1 Tests first: bread never crowds out iron; output with nowhere to go stays; room is not promised twice; output leaves once room opens
- [x] 2.2 Destination choice by room for the good, with units on their way counted (design D2)
- [x] 2.3 `BuildingIssue.outputStuck(Good)` and the inspector text (design D3)

## 3. Rest rule out

- [x] 3.1 Measure per-good storage with the rest rule on and off (design D4)
- [x] 3.2 Remove `restAt`, the rest check, `.resting` and the inspector's resting line

## 4. Rivals

- [x] 4.1 Warehouse trigger on room for food; surplus sales per good; drop the unreachable full-town-center rules (design D5); tests

## 5. Saves

- [x] 5.1 v9 → v10 migration keeping overflow, v9 fixture, tests (design D8)

## 6. Pacing and guards

- [x] 6.1 Research retune sweep; set ×18 (design D6)
- [x] 6.2 Final configuration: pacing, first-hour solvency with the aggregate control, guided Hard start, rival viability against main

## 7. Wrap-up

- [x] 7.1 `make lint`, `make format`, `openspec validate per-good-storage --strict`, `SCENARIO_COVERAGE_STRICT=1 make test-scenarios`, diff coverage 100%, determinism fixture twice
