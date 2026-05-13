## MODIFIED Requirements

### Requirement: Quit to Title row appears in the shipped app shells

The `Quit to Title` row SHALL be visible whenever the pause menu is shown in either the iOS or macOS app shell. The row's visibility was previously gated by an app-shell-injected `onQuitToTitle` that both shells passed as `nil` (hiding it). After this change the row's visibility no longer depends on shell wiring — the `TitleScreenHost` supplies the closure.

#### Scenario: Quit to Title is visible on the macOS shell

- **WHEN** the player opens the pause menu in the live macOS app
- **THEN** the action list contains exactly: Resume, Save Game, Settings, Quit to Title, Quit (in that order)

#### Scenario: Quit to Title is visible on the iOS shell

- **WHEN** the player opens the pause menu in the live iOS app
- **THEN** the action list contains exactly: Resume, Save Game, Settings, Quit to Title (in that order)
