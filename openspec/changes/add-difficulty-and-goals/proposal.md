## Why

The game direction asks for a difficulty chosen at new game, next to the age and culture, and for goal-based scenarios beside the endless sandbox. Today every game starts with the same money and rules and never ends unless the treasury runs dry.

## What Changes

- **Difficulty:** Easy, Normal or Hard, chosen at new game.

  | | Easy | Normal | Hard |
  |---|---|---|---|
  | Starting money | $1,500 | $1,000 | $700 |
  | Starting wood / planks / food | 10 / 8 / 4 | 6 / 5 / 2 | 4 / 3 / 1 |
  | Upkeep | 75% | 100% | 125% |
  | Bankruptcy grace | 150 ticks | 50 ticks | 30 ticks |
  | Chance of a history event each year | 50% | 50% | 65% |
  | Harmful events | never | as drawn | twice as likely |

- **Goals:** a game is either a sandbox (no goals, as today) or a scenario with a list of goals. Three goal kinds: reach a population, reach an age, hold a stock of a good. Progress is tracked every tick; when every goal is met, the scenario is won.
- **Scenarios:** three built-in scenarios offered in the New Game dialog:
  - **First Harvest** (Antiquity, Easy): 40 residents and 20 bread in store.
  - **The Guild Town** (Medieval, Normal): 30 merchants' residents and 30 tools in store.
  - **Steam and Smoke** (Renaissance, Hard): reach the Industrial age.
- **HUD:** in a scenario, a goals panel lists each goal with its progress, and winning shows a banner and a "Scenario complete" sheet with Keep Playing and Quit to Title.
- **Saves:** a v7 → v8 migration makes existing saves Normal sandbox games.

## Capabilities

### New Capabilities

- `difficulty-and-goals`: difficulty settings, goals, scenarios and winning.

### Modified Capabilities

- `persistence-save-load`: the v7 → v8 migration.
- `platform-shells`: difficulty and mode pickers, goals panel, win sheet.

## Impact

- **CityCore:** `Difficulty`, `Goal`, `Scenario`, `World.difficulty`, `World.goals`, `WorldEvent.scenarioWon`, difficulty-aware economy and history events, `newGame(... difficulty:scenario:)`.
- **CityPersistence:** save version 8.
- **CityUI:** pickers, goals panel, win sheet.
