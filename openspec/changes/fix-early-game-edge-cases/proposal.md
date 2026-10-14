## Why

A headless playtest found two early-game holes. After bankruptcy ends the game, the player can still demolish, clear forest, choose research and edit routes, so a lost town keeps changing. And on Normal, rats in the granary fired three times in the first five years while the town had no food, announcing a loss that never happened.

## What Changes

- Once the game is over, the world drops every player command without changing anything and without emitting events. Rival turns, saving and loading are unaffected.
- Rats in the granary fires only when an operational player goods buffer holds food. In a year where rats is drawn and no food is stored, no history event fires: nothing changes and no `historyEvent` is emitted.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `economy`: game over stops player commands.
- `calendar-and-events`: rats in the granary skips a town with no stored food.

## Impact

- CityCore: `World.tick` command application and the calendar system's history-event step.
- The determinism fixture's event log can change for seeds where rats lands on an empty granary; it stays deterministic.
- No new build-time tools.
