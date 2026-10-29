## Why

The game has one downloaded music track. The owner wants original music, composed by us and rendered in the repository from text, with no samples. It should be period folk in several moods, so the music director can give the menu, the build, the market season and the winter their own pieces.

## What Changes

- **A score language.** It lives in `scripts/audio/music/score.py`. A piece is a list of sections, each with a chord per bar, a melody of `note:beats` tokens, a lead instrument and its accompaniment parts (`harp`, `lute`, `drone`, `drum`). The arranger rolls the harp chords, breaks the lute chords into eighths, holds the drone on the tonic and fifth, and beats the frame drum on the strong beats. Timing (about ±15 ms) and velocity are humanised with a seeded random-number generator.
- **An offline band.** It lives in `scripts/audio/music/synth.py` and uses no samples:
  - Karplus–Strong plucked strings, tuned exactly with a fractional-delay allpass: a lute (paired gut courses) and a wire harp;
  - an additive recorder with breath noise and blooming vibrato;
  - a hurdy-gurdy drone;
  - a frame drum (skin and rim);
  - a small stone hall (Schroeder combs and allpasses).
- **Deterministic rendering.** It uses numpy only for elementwise arithmetic and our own polynomial sine. Recursive filters run per sample or in blocks no shorter than their delay. The music is mono IMA4 at 32 kHz, so each piece stays under the repository's 3 MB file cap.
- **Five original pieces:**

  | Piece | Use | Mode | Time |
  |---|---|---|---|
  | The Bridge at Dawn | title theme, loops | D Dorian | 3/4 |
  | Hearth and Harvest | calm build theme | G Mixolydian | 4/4 |
  | Market Day | lively summer dance | D Mixolydian | quick 3 |
  | The Long Night | sparse winter piece, no drum | A Aeolian | slow 4/4 |
  | Ships on the Sound | spring and autumn | E Dorian | 4/4 |

- **Bindings.** The title theme is `music.title`. The rest join `bards-tale` in the game tracks, with season tags. `bards-tale` stays, untagged, credited as before.
- **Credits.** Each piece's manifest entry reads "(original, generated in-repo)" by "Citybuilder original score", under CC0, so the existing credits view lists it.
- **Checks.** `make music` renders the pieces and `make music-check` fails if a committed file differs. A pytest test runs the check on macOS. A new `audio-linux` CI job runs the sound and music checks on Linux and replaces the step in the `changes` job.

## Capabilities

### New Capabilities
- (none)

### Modified Capabilities
- `audio-playback`: a new requirement, "Original music is composed and rendered in the repository".

## Impact

- **New:** `scripts/audio/music/` (synth, score, pieces, render), `scripts/tests/test_music.py`, five files in `Resources/Audio/music/`, the `music` and `music-check` Makefile targets, and `PYTHON` for the audio targets.
- **Changed:** `bindings.json` (title, tracks and season tags), `manifest.json`, and CI (the `audio-linux` job, part of `ci-ok`).
