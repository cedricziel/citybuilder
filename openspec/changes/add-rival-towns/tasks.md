## 1. M1 — Ownership and rival setup

- [ ] 1.1 Tests-first: translate the buildings-and-construction, sea-transport, economy and population-and-needs scenarios, and the rival-towns scenarios "Rivals in archipelago games", "Rival identity", "Rival purse" and "Rivals don't share the player's effects", into failing `CityCoreTests`. Confirm red.
- [ ] 1.2 Implement to green: `Owner`, `RivalID`, `RivalTown`, `RivalColour`, `Building.owner` and `Ship.owner` with tolerant decoders, `World.rivals`, home and rival island selection, rival cultures, colours and treasuries, `newGame(... rivals:)`, `owner(ofIsland:)`, owner-aware `canPlace` with `.foreignIsland`, demolish and harvest guards, per-owner tax and upkeep, `goodsBuffers(of:)` and the player-only filters (design D1–D3, D7).

## 2. M2 — Rival AI

- [ ] 2.1 Tests-first: translate "Rival turns go through the command queue", "Rival build order", "Rival town plan", "Rival ages" and the simulation-core scenarios into failing `CityCoreTests`. Confirm red.
- [ ] 2.2 Implement to green: `Command.rivalPlace`, `applyPlace(... owner:)` with silent rival rejections, `RivalAIState`, threshold rules and script, affordability, wait-and-skip, caps, the block grid and slot search, `runRivalSystem` with staggered turns, rival ages and `WorldEvent.rivalAgeAdvanced` (D4–D6, D8).
- [ ] 2.3 Extend the performance budget test to a Hard archipelago world with three rivals after 3,000 ticks; keep it inside the existing budget.

## 3. M3 — Standings, goal and scenario

- [ ] 3.1 Tests-first: translate "Standings", "Outgrow every rival" and "Island Rivalry scenario". Confirm red.
- [ ] 3.2 Implement to green: `World.standings()`, `Goal.outgrowRivals` and its progress, `Scenario.requiredLayout`, `Scenario.islandRivalry` (D9).

## 4. M4 — Persistence

- [ ] 4.1 Tests-first: translate "v8 save loads without rivals" with a v8 archipelago fixture. Confirm red.
- [ ] 4.2 Implement to green: `MigrationV8ToV9`, `SaveFile.currentVersion = 9` (D12).

## 5. M5 — Rendering and UI

- [ ] 5.1 Tests-first: translate the rendering-2_5d scenarios into failing `CityRender2DTests` and the platform-shells scenarios into failing `CityUITests`. Confirm red.
- [ ] 5.2 Implement to green: snapshot `rivals`, `culture(for:)` and `age(for:)`, owner-based `CultureSprites` lookup, resident names by owner culture, pennant texture and node (D10).
- [ ] 5.3 Implement to green: New Game toggle and Island Rivalry layout lock, standings panel, foreign-island text, rival inspector, rival island overlay, rival age banner (D11).

## 6. M6 — Verification

- [ ] 6.1 Runtime check: start a Hard archipelago sandbox, pan to the south-east island and watch the rival lay roads and build with pennants in its own culture; try to place a house there and see the rejection; open the standings panel. Let the game run for 6,000 ticks (10 simulated minutes) and record each rival's population, age and wealth from the standings panel.
- [ ] 6.2 Run lint, format, `make test`, `make test-scenarios` and `openspec validate add-rival-towns --strict`.
