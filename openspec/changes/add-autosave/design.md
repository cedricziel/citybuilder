## Decisions

**D1. Coordinator in CityPersistence, glue in the apps.** `AutosaveCoordinator` takes a `SaveStore`, an `AutosaveClock` and a world provider, so tests inject the clock and a faulting `FileWriter`. `CityUI` does not link `CityPersistence`; `GameSession` only exposes hooks (`onPlayStep`, `onSeasonChange`, `lastAutosave`) and `Apps/Shared/AutosaveHub.swift` connects them.

**D2. Interval counts play, not idle time.** The shell calls `playStepped()` after every step that ran; a paused game does not step. The interval compares the injected clock to the last attempt. A town whose tick count equals the last saved tick is never rewritten.

**D3. Serial queue, one follow-up.** Writes run on one serial queue. A trigger while a write runs sets one pending flag; when the write ends, one more write takes a fresh snapshot. Leaving the foreground uses `queue.sync` so it queues behind a running write and returns only when the file is written (the system may suspend the process right after).

**D4. Backup only from a good file.** Before writing, the current main file is decoded; only if it decodes does it become `<id>.json.bak`. A corrupt main file never replaces a good backup. A failed backup write does not stop the save.

**D5. Load falls back inside `SaveStore.load`.** All three shells and the title screen already call it, so Continue needs no change. The save's own error is thrown when the backup fails too.

**D6. Bankrupt, lost, unplayed.** `AutosavePolicy.allows` is false at tick 0, when bankrupt (`economy.gameOver`), and when `scenarioLoss` is set. A new game therefore never overwrites the slot before it is played. UI-test launches disable the hub; they also use their own save folder.

**D7. iCloud on Apple TV.** An autosave calls `TVSaveSync.didSave` like a manual save. Conflicts are only reported at launch, and an upload that finds a newer iCloud copy stays pending, so autosaves cannot start a prompt loop. The `.bak` file is not a `.json` save: it is not listed, not uploaded.

**D8. Mac quit.** `willTerminate` saves, so Cmd-Q keeps progress. The pause menu's Quit Without Saving stops the coordinator first so it is honoured.

**D9. Scene phase.** iOS, iPadOS and Apple TV save on `.background` (not `.inactive`, which fires for a pulled-down shade). The Mac saves on `.background` and on `willTerminate`.

## Not done

Save slots, a load list and several backups (#409 parts 2 and 3).
