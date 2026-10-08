## Context

See proposal.md (Why). Economy constants live on `Economy` (starting balance, upkeep interval, bankruptcy grace). History events are decided per year from the seed. `newGame(layout:seed:culture:age:)` builds a world; saves are at version 7.

## Decisions

### D1 — `Difficulty` is a stored enum with a settings table

`Difficulty` (`easy`, `normal`, `hard`) exposes `startingBalance`, `starterStock`, `upkeepPercent`, `bankruptcyGraceTicks`, `eventChancePercent` and `harmfulEventWeight` (0, 1, 2). `World.difficulty` defaults to Normal so fixtures keep today's numbers. The economy system multiplies upkeep by `upkeepPercent / 100` (rounded down, at least 1 when any upkeep is due) and reads the grace from the difficulty.

### D2 — Difficulty shapes history events

`historyEvent(forYear:)` fires when `first draw % 100 < eventChancePercent` and picks from a weighted list where `ratsInTheGranary` has weight `harmfulEventWeight` and the others weight 1 each. On Normal this keeps a 50% chance but changes which draws fire, which is acceptable because no save depends on future events.

### D3 — Goals

`Goal` is an enum: `.population(Int)`, `.age(Age)`, `.stock(Good, Int)` (summed over goods buffers). `World.goals: [GoalState]` holds each goal and whether it is met; met goals stay met. A goals system runs every 10 ticks; when the last goal becomes met, `World.scenarioWon` is set and `WorldEvent.scenarioWon` fires once.

### D4 — Scenarios

`Scenario` is a small static catalog (`firstHarvest`, `guildTown`, `steamAndSmoke`) with title, blurb, age, difficulty and goals. `newGame(layout:seed:culture:scenario:)` applies the scenario's age, difficulty and goals; the sandbox path takes an explicit difficulty.

### D5 — UI

The New Game dialog gains a mode picker (Sandbox / Scenario). Sandbox shows difficulty, age and culture; Scenario shows the scenario list with its blurb and culture (age and difficulty come from the scenario). The HUD shows a goals button in scenarios, opening a panel with each goal's text and progress ("Residents 24/40"). On `scenarioWon` the session shows a banner and presents a sheet; Keep Playing dismisses it.

### D6 — Migration v7 → v8

Adds `difficulty: "normal"`, `goals: []`, `scenarioWon: false`. `SaveFile.currentVersion` becomes 8.

## Risks / Trade-offs

- **[Risk] Scenario numbers are untested by play** → Mitigation: a runtime check of First Harvest; constants live in one table.
