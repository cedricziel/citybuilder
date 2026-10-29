## ADDED Requirements

### Requirement: Music follows the title screen, the game and the season

A `MusicDirector`, ticked by wall-clock time, SHALL choose the music:

- **On the title screen.** The `music.title` track SHALL play and start again each time it ends. Without a title track, the title SHALL use the in-game choice.
- **In a game.**
  - Each track SHALL play once.
  - The director SHALL then wait `gapSecondsBetweenTracks` (default 30) and start the next track.
  - It SHALL pick the next track with the no-repeat-within-last-two shuffle, among the tracks whose `seasons` include the current season or that have no `seasons`. If no track fits, it SHALL pick among all tracks.
- **When the context changes** (a game starts or ends):
  - the playing track SHALL fade out over `crossfadeSeconds` (default 3);
  - the new context's track SHALL fade in over the same time, at once, with no gap.
- **With no music bound,** nothing SHALL play.

#### Scenario: The title theme plays on the menu
- **WHEN** the app starts with a title track bound
- **THEN** the title track starts, and starts again when it ends

#### Scenario: Starting a game crossfades to game music
- **WHEN** a game starts while the title theme plays
- **THEN** the title theme fades out over 3 seconds while a game track fades in

#### Scenario: Game tracks are separated by the gap
- **WHEN** a 60-second game track ends
- **THEN** nothing new starts for 30 seconds, and then the next track starts

#### Scenario: The season leans the choice
- **WHEN** it is winter and one track is tagged winter, one summer and one untagged
- **THEN** the summer track is never chosen

#### Scenario: Returning to the title brings back its theme
- **WHEN** the game ends while a game track plays
- **THEN** the game track fades out and the title theme fades in
