## Why

Saving is manual. Only Apple TV reacts to the app leaving the foreground, so on iPhone, iPad and Mac a quit or a kill loses everything since the last visit to the pause menu. The existing Autosave requirement in `persistence-save-load` was never built. Part of #409 (epic #396); save slots and the load list stay open on #409.

## What Changes

- Autosave into the one existing slot, so Continue picks it up, on three triggers: the app leaves the foreground or is about to terminate, a season change, and five minutes of wall-clock play.
- Triggers live in the app shell and a coordinator in `CityPersistence`. The simulation never reads the clock.
- No autosave for an unplayed town, a bankrupt town, a lost scenario, or a UI-test seeded launch.
- The snapshot is taken on the main actor; encoding and writing run on a serial queue. Triggers coalesce. Leaving the foreground writes before returning, because the system may suspend the process.
- The previous autosave is kept as one backup file. Continue falls back to it when the main file fails to load.
- Failed autosave: the existing session banner. Success: a line in the pause menu ("Autosaved 2 minutes ago"), English and German.
- The disk writer replaces the target with `replaceItemAt`, so a crash between remove and move can no longer lose the save.

## Capabilities

### Modified Capabilities
- `persistence-save-load`: Autosave rules, backup file, load fallback, atomic replace.
- `platform-shells`: Triggers per platform, feedback, Mac quit without saving.

## Impact

`Packages/CityPersistence` (new `Autosave.swift`, `SaveStore`, `FileWriter`), `Packages/CityUI` (session hooks, banner, pause line), `Apps/Shared/AutosaveHub.swift`, the three app shells, String Catalogs.
