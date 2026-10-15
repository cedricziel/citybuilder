## Why

A headless playtest found two early-game holes. After bankruptcy ends the game, the player can still demolish, clear forest, choose research and edit routes, so a lost town keeps changing. And on Normal, rats in the granary fired three times in the first five years while the town had no food, announcing a loss that never happened.

## What Changes

- Once the game is over, the world drops every player command without changing anything and without emitting events. Rival turns, saving and loading are unaffected.
- Rats in the granary fires only when it would spoil something: an operational player goods buffer must hold at least 2 food. Otherwise no history event fires that year: nothing changes and no `historyEvent` is emitted.
- The game screen shows a persistent bankruptcy banner once the game is over, saying why it ended and what the player can still do. The build rail, the tile menu and research are disabled, and any armed tool or pending placement is cleared.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `economy`: game over stops player commands.
- `calendar-and-events`: rats in the granary skips a town with less than 2 food in any store.
- `platform-shells`: game-over banner, and build, demolish and research disabled after game over.

## Impact

- CityCore: `World.tick` command application and the calendar system's history-event step.
- CityUI: `GameSession` banner and tool gating, the build rail, and the research button.
- The determinism fixture's event log can change for seeds where rats lands on an empty granary; it stays deterministic.
- No new build-time tools.
