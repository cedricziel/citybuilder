## ADDED Requirements

### Requirement: A new game ends the old one first

When the title screen commits a new game while one is running, it SHALL end the old game session before creating the new one, so the old game's end handlers run before the new game's sounds start.

#### Scenario: A new game ends the old one before it starts
- **WHEN** a game is committed while another is running
- **THEN** the old session's end handler runs before the session factory creates the new session
