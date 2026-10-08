## Why

When the most recent save can't be loaded, for example because a model change makes old JSON undecodable, the title screen's Continue button does nothing. `SaveStore.load` already throws a `SaveError`. `TitleScreenViewModel.continueRequested()` swallows that error with `try?` and returns, so the player gets no message and the logs record nothing.

## What Changes

- `TitleScreenViewModel` keeps the load error in a new `loadFailure` state instead of dropping it, and logs the underlying error through `os.Logger`.
- `TitleScreenView` shows an alert, "This save could not be loaded", when `loadFailure` is set. Dismissing the alert clears it.
- The title screen stays usable after a failure. New Game and Settings still work, and no session is committed.

## Capabilities

### Modified Capabilities

- `persistence-save-load`: adds a requirement that a failed load from the title screen is shown to the player and logged.

## Impact

- `Packages/CityUI/Sources/CityUI/TitleScreenViewModel.swift`, `TitleScreenView.swift`
- `Packages/CityUI/Tests/CityUITests/TitleScreenViewModelTests.swift`
- No change to `CityPersistence`: `SaveStore` already reports decode failures as `SaveError.integrityFailed`.
