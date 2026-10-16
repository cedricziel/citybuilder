## Why

The music system plays one bound track as an endless loop, starting at launch. It ignores the shuffle, the gap between tracks and the playlist the spec describes, and it plays the same music on the title screen and in the game. Original music is coming, several pieces written in the repository, so the music needs its own director first:
- a title theme on the menu;
- in-game pieces shuffled with a gap between them, leaning toward the season's mood;
- a crossfade whenever the context changes.

## What Changes

- **New `MusicDirector`.** It is driven by wall-clock time from the audio layer's 10 Hz timer.
  - **Title screen.** Its `title` track plays and repeats. Without one, it uses the in-game shuffle.
  - **In a game.** Each track plays once, then the director waits the configured gap (30 s by default) and picks the next. The pick uses the existing no-repeat-within-last-two shuffle, among the tracks tagged for the current season or untagged; if none fit, it picks among all tracks.
  - **Changing context.** Starting a game or returning to the title fades the playing track out and the new one in, over `crossfadeSeconds` (default 3).
- **`bindings.json`.** The `music` section gains:
  - `title`, the title theme;
  - `crossfadeSeconds`;
  - per-track `seasons` mood tags.
- **New `MusicVoice`.** It plays one track on the `music` bus with volume ramps, and is released after it fades out.
- **App shells.** They tell the audio layer when a game starts: `AudioStack.beginSession()`, through `GameSession` creation. It already hears when a game ends. The season comes from the game's snapshots.

## Capabilities

### New Capabilities
- (none)

### Modified Capabilities
- `audio-playback`: a new requirement, "Music follows the title screen, the game and the season". It covers the existing "Music shuffle policy": the shuffle now runs, with the gap, in game.

## Impact

- **CityAudio:**
  - `Bindings.MusicSection` gains `title` and `crossfadeSeconds`; `MusicTrack` gains `seasons`.
  - New `MusicDirector` and `MusicVoice`.
  - `MusicPlaylist` gains a candidate filter.
  - `AudioStack` replaces `startMusicIfAvailable` with the director, and gains `beginSession()`.
- **Apps:** each session factory calls `audio.beginSession()`.
- **Music files:** none added here. `bards-tale` stays the only in-game track until the original pieces land.
