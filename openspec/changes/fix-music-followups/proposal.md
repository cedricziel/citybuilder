## Why

The review of the music director and the original music found five problems:

- **The clock lags.** It added a fixed 0.1 s per timer firing, and the timer ran only in the default run-loop mode. So the music stalled while the player scrolled or held a menu open, and lagged under load.
- **A new game starts with the old season.** The previous game's season picked the first track of the next game.
- **The title theme has a gap.** It restarted after a gap of up to a tenth of a second, instead of looping.
- **CI.** The audio check ran with the sprite pipeline's selection, and the macOS pytest rendered all the music a second time.
- **The pluck's tuning filter could ring.** Its allpass fraction could approach 0, which rings.

## What Changes

- **Measured clock.** `AudioStack` measures elapsed time with `ContinuousClock` and runs its timer in the common run-loop modes.
- **Season reset.** `MusicDirector` forgets the season when it returns to the title.
- **Looping title theme.** The title theme plays as a looping voice. The director starts it once.
- **CI selection.** `changes` gains an `audio` output, true for changes to the audio sources, the renders, their tests, the Makefile, `requirements.txt` or the workflow. `audio-linux` runs on it. The full music render test is marked slow and runs only with `AUDIO_SLOW_TESTS` set.
- **Pluck fraction.** It stays in [0.1, 1.1). Every piece is re-rendered once, in one commit.
- **Size test.** It measures the committed files.
- **`render.py --only`.** An unknown path is now an error, before anything renders or the manifest changes. The docstring no longer documents a `--preview` flag that doesn't exist.
- **README.** `scripts/audio/README.md` asks for batched, piece-by-piece music renders, to keep the repository small.

## Capabilities

### New Capabilities
- (none)

### Modified Capabilities
- `audio-playback`: a new requirement, "Music keeps real time and loops its title theme".
- `platform-shells`: a new requirement, "A new game ends the old one first".

## Impact

- **CityAudio:** `AudioStack`, `MusicDirector` and `EngineCuePlayer.playMusic(_:fade:loops:)`.
- **Tests:** CityUI and CityAudio tests.
- **scripts/audio:** `synth.py`, the tests and the README.
- **CI:** `ci.yml`.
- **Resources:** the five music files, re-rendered once.
