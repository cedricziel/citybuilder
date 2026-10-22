## ADDED Requirements

### Requirement: Music keeps real time and loops its title theme

The audio layer SHALL advance the music director and the ambient scene by the wall-clock time measured between timer firings, and the timer SHALL fire in the common run-loop modes, so menus and scrolling don't stall the music. The title theme SHALL play as a looping voice that the director starts once. Returning to the title SHALL clear the director's season. A track that fails to play (its file won't load, or the engine won't start) MUST NOT count as playing: the director SHALL try again on the next tick.

#### Scenario: The title theme loops without a restart
- **WHEN** a 20-second title theme has played for a minute
- **THEN** the director has started it exactly once, as a loop

#### Scenario: Game, title and game again
- **WHEN** a game starts, the player returns to the title, and another game starts
- **THEN** each change fades the playing track out and the next one in, and the title theme starts as a loop each time

#### Scenario: A new game starts without the last game's season
- **WHEN** a winter game ends and the title returns
- **THEN** the director has no season until the next game's first snapshot

#### Scenario: A track that fails to play is tried again
- **WHEN** a game track fails to play
- **THEN** the director does not wait out its length, and tries again on the next tick
