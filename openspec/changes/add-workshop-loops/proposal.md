## Why

Only the sawmill and the lumberjack have working sounds, and even those barely play:

- **Loops are keyed by file.** `EngineCuePlayer` keys loop players by file path, so the first sawmill's loop is the only sawmill loop. It plays at that sawmill's position, wherever the others are.
- **Stopping never reaches the player.** `AudioCoordinator.stopLoop(for:)` only forgets the entity. A stalled or demolished workshop keeps sawing.
- **A busy workshop never starts its loop.** Loops start only on `productionResumed`, which needs a stall first.

Every other workshop is silent. And the shipped `bindings.json` does not even decode: its `productionStalled` stop cues leave out `bus`, which the decoder requires. `AudioBundleLoader` swallows that error and falls back to empty bindings, so the game plays none of its bound sounds, not even its music track.

## What Changes

- **Stop cues may leave out `bus`.** Start cues still must name it. With this, the shipped bindings decode again.

- **One loop per building.** Loop players are keyed by the building's entity. The coordinator's stop reaches the cue player, which stops and detaches the player.
- **Nearest loops play.** At most 8 workshop loops play at once: the 8 nearest the listener, re-chosen when the listener moves.
- **Loops start with the first cycle.** A workshop's loop also starts with its first finished cycle (`productionCycleCompleted`). It still stops when production stalls.
- **New generated loops.** Seven loops cover every producing kind:

  | Loop | Kinds |
  |---|---|
  | Fields | farm, grain farm, hop garden, vineyard, tea garden, coffee grove |
  | Mill | windmill, quern house |
  | Oven fire | bakery, charcoal burner, roastery |
  | Forge | smelter, toolsmith |
  | Mine | mine |
  | Brewing vat | brewery, winery, tea house |
  | Shipwright's mallet | shipyard |

## Capabilities

### New Capabilities
- (none)

### Modified Capabilities
- `audio-playback`: three new requirements, "Every workshop has a work loop", "Loop players follow their buildings" and "Stop cues need no bus".

## Impact

- **CityAudio:**
  - `DispatchedCue` carries the event's entity.
  - `AudioCoordinator` takes a stop handler.
  - `EngineCuePlayer` keys loops by entity and plays the nearest 8 through a pure `LoopSelection`.
  - `AudioStack` wires the stop handler and passes listener moves on.
- **Resources:** seven new loops in `Resources/Audio/loop/`, their manifest entries, and the producer bindings in `bindings.json`.
- **scripts/audio:** seven new recipes.
