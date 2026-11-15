## 1. Persistence
- [x] 1.1 `AutosaveCoordinator`, `AutosaveClock`, `AutosavePolicy`
- [x] 1.2 `SaveStore.autosave` with single backup; `load` falls back to it
- [x] 1.3 Atomic replace in `AtomicDiskWriter`
- [x] 1.4 Tests: coalescing, season, interval, finished games, backup fallback, failed write

## 2. UI and shells
- [x] 2.1 Session hooks, failure banner, pause-menu line, English and German strings
- [x] 2.2 `AutosaveHub` and the iOS, Mac and TV shells

## 3. Verify
- [x] 3.1 `make lint`, `make l10n-check`, `openspec validate add-autosave --strict`
