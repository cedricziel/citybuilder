## Why

Only the sawmill and the lumberjack have working sounds, and even those barely play:

- **Loops are keyed by file.** `EngineCuePlayer` keys loop players by file path, so the first sawmill's loop is the only sawmill loop. It plays at that sawmill's position, wherever the others are.
- **Stopping never reaches the player.** `AudioCoordinator.stopLoop(for:)` only forgets the entity. A stalled or demolished workshop keeps sawing.
- **A busy workshop never starts its loop.** Loops start only on `productionResumed`, which needs a stall first.

Every other workshop is silent. And the shipped `bindings.json` does not even decode: its `productionStalled` stop cues leave out `bus`, which the decoder requires. `AudioBundleLoader` swallows that error and falls back to empty bindings, so the game plays none of its bound sounds, not even its music track.

## What Changes

- **Stop cues may leave out `bus`.** Start cues still must name it. With this, the shipped bindings decode again.

- **Broken audio files are reported.** A present-but-broken `bindings.json` or `manifest.json` is now reported as a fault in the system log, instead of failing silently.
- **A session's loops end with it.** Quit to Title ends the game session; the app shell then calls `AudioStack.endSession()`, which stops every building loop and clears the coordinator. Music and ambient play on.
- **One loop per building.** Loop players are keyed by the building's entity. The coordinator's stop reaches the cue player, which stops and detaches the player.
- **Nearest loops play.** At most 8 workshop loops play at once: the 8 nearest the listener, re-chosen when the listener moves. A playing loop gets a 3-tile margin, so panning along the boundary doesn't swap loops, and loops fade in and out over 0.25 s.
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
- `audio-playback`: five new requirements: "Every workshop has a work loop", "Loop players follow their buildings", "Stop cues need no bus", "A session's loops end with it" and "A broken audio document is reported".

## Impact

- **CityAudio:**
  - `DispatchedCue` carries the event's entity.
  - `AudioCoordinator` takes a stop handler.
  - `EngineCuePlayer` keys loops by entity and plays the nearest 8 through a pure `LoopSelection`.
  - `EngineCuePlayer` hands building loops to `EntityLoopMixer`, which keeps one `PlayerLoopVoice` (fading, generation-guarded re-scheduling) per chosen building.
  - `AudioStack` wires the stop handler, passes listener moves on, and adds `endSession()`.
  - `AudioBundleLoader` reports load failures.
- **CityUI:** `GameSession.onEnd`/`end()`; the title screen ends the session it drops.
- **Apps:** each shell's session factory sets `onEnd` to `audio.endSession()`.
- **Resources:** seven new loops in `Resources/Audio/loop/`, their manifest entries, and the producer bindings in `bindings.json`.
- **scripts/audio:** seven new recipes.
