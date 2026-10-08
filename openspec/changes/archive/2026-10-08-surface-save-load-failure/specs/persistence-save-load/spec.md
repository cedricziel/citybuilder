## ADDED Requirements

### Requirement: Failed load is visible on the title screen

When the player picks Continue and the save fails to load (unreadable file, unknown version, decode failure, or integrity failure), the title screen SHALL show an alert that says "This save could not be loaded". The underlying error MUST be written to the system log. The title screen MUST NOT commit a game session, and New Game MUST stay available.

#### Scenario: Undecodable save shows a load-failure alert

- **WHEN** the player picks Continue and the most recent save cannot be decoded
- **THEN** the title-screen view-model exposes a load-failure state, no game session is committed, and the title screen shows "This save could not be loaded"

#### Scenario: New Game still works after a failed load

- **WHEN** a Continue load has failed and the player dismisses the alert and picks New Game
- **THEN** the load-failure state is cleared and the New Game dialog opens
