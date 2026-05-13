## Context

`add-game-pause-menu` added the `Quit to Title` row, gated on a non-nil `onQuitToTitle` closure injected by the app shell:

```swift
// PauseMenuViewModel.actions
if onQuitToTitle != nil {
    actions.append(
        PauseMenuAction(kind: .quitToTitle, label: "Quit to Title", systemImage: "house")
    )
}
```

Both app shells today pass `onQuitToTitle: nil`, so the row never appears:

```swift
// CitybuilderiOSApp + CitybuilderMacApp (same shape)
pauseMenuFactory: { [saveStore] session in
    PauseMenuConfig(
        platform: .iOS,
        onSaveGame: { try saveStore.save(session.world, gameID: Self.defaultGameID) },
        onQuitToTitle: nil,                // ← this change wires it
        onQuit: nil
    )
}
```

`add-title-screen-and-new-game` shipped a host (`TitleScreenHost`) whose body reacts to `viewModel.committedSession`:

```swift
public var body: some View {
    if let session = viewModel.committedSession {
        gameView(session: session)
    } else {
        titleView
    }
}
```

The mechanical fix — "clear `committedSession`" — is one line. The interesting design decision is where to plumb it.

## Goals / Non-Goals

**Goals**
- The pause-menu `Quit to Title` row appears in both shipped apps.
- Tapping it returns the player to the title screen with the just-auto-saved game listed under `Continue`.
- The host owns the lifecycle seam: app shells don't have to know `TitleScreenViewModel` exists.

**Non-Goals**
- A confirmation dialog before quitting (auto-save makes it non-destructive).
- Save-slot management UI on the title screen.
- A separate "Restart" or "New Game from in-game" path (the player can already do this via `Quit to Title → New Game…`).

## Decisions

### D1. Add a `returnToTitle()` method, not a public setter

`TitleScreenViewModel.committedSession` is `private(set)` so external code can't accidentally desync it from the host's view-builder. The cleanest extension is a verb-named method:

```swift
public func returnToTitle() {
    committedSession = nil
    refreshMostRecentSave()        // pick up the auto-save we just wrote
}
```

This pairs naturally with the existing `commit(world:)` that flips it on. The method also refreshes `mostRecentSave` so the player immediately sees the save that just happened in their `Continue` row.

**Why over alternatives**
- *Make the setter `public`*: would let any view bypass the host's state machine. Easy to misuse.
- *Expose a publisher / closure*: more machinery than the situation needs.

### D2. The host wraps `pauseMenuFactory` rather than asking the app to inject the callback

The app shells already supply `pauseMenuFactory: (GameSession) -> PauseMenuConfig?`. The host can wrap whatever config the shell produces and inject its own `onQuitToTitle`:

```swift
private func gameView(session: GameSession) -> some View {
    let injectedConfig = pauseMenuFactory(session).map { config in
        PauseMenuConfig(
            platform: config.platform,
            onSaveGame: config.onSaveGame,
            onQuitToTitle: { [weak viewModel] in viewModel?.returnToTitle() },
            onQuit: config.onQuit
        )
    }
    // ...
}
```

The app shells stop caring about the title-screen lifecycle. They keep the `onSaveGame` closure they already built (used by the pause-menu's stand-alone Save row) and let the host drop in the title transition.

**Why over alternatives**
- *Add a third parameter to the shell-supplied factory*: leaks the view-model into shell code. Cleaner to centralize the binding in the host where the view-model already lives.
- *Mutate the config in-place*: `PauseMenuConfig` is a value type; rebuilding is the natural move.

### D3. Auto-save runs through the existing pause-menu path, not duplicated in the host

`PauseMenuViewModel.invoke(.quitToTitle)` already executes `try? onSaveGame()` before calling `onQuitToTitle?()`. The host's injected `onQuitToTitle` runs *after* that save attempt, so it does NOT need to re-save. This is the spec-D7 behavior of `add-game-pause-menu`: silent best-effort save first, then transition. The host adds the transition; the save is already handled.

### D4. Re-entering the game keeps the same `TitleScreenViewModel`

After returning to title, the player can tap `Continue` or `New Game…` again. The host's `@State private var viewModel: TitleScreenViewModel` is the same instance — `committedSession` simply re-populates through the same factory closure that built the previous session. No special "second game" path.

The audio engine, the save store, and the session factory closure all live on the app shell and survive the title round-trip unchanged.

## Risks / Trade-offs

- **Stale `GameSession` retention**: when `committedSession` flips to `nil`, the previous `GameSession`'s 10 Hz timer must stop firing or it leaks main-actor work. The existing `GameSession` deinit invalidates `tickTimer`; the host releasing the reference triggers deinit. Verified by an existing CityUI test that checks the timer stops when the session deallocates.
- **Auto-save race**: the player taps Quit to Title; the save closure throws; the title still appears. The spec already accepts this (spec D7). The failure is logged; no user surface beyond that. A future "save failed" toast is out of scope here.
- **Pause-state on return**: when the player returns to title, the prior `GameSession` is being torn down — `isPaused` no longer matters. A *new* `GameSession` built later starts `isPaused = false` by spec. No carryover concern.

## Migration Plan

No data migration. No save-format change. Rollback is a clean revert of the wiring commits.

## Open Questions

- **Audible sound when returning to title?**: currently nothing plays. A subtle close-out cue is `add-title-screen-art` territory.
- **iCloud "Continue" from another device**: still future work; the title screen surfaces the local store only.
