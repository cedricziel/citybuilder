## Why

The game's sound is thin, and four of its files are placeholders: the sawmill and lumberjack loops, the carrier clink and the forest-birds bed. They were made with ffmpeg test-tone synthesis and are marked "replace before ship". The owner wants sounds we author ourselves rather than download, with levels that match from one sound to the next. Before we can add sound for the many events that are still silent, we need a way to make sounds that is reproducible and reviewable.

## What Changes

- A procedural sound generator under `scripts/audio/`, in standard-library Python.
  - Each sound is a recipe built from struck wooden and metal modes, filtered noise, gliding tones and small-room reflections.
  - The generator writes mono IMA4 `.caf` files, the format the game already uses. It encodes them itself, so the bytes are identical on every machine. It uses its own sine, exponential and random-number generator, never libm's.
  - It normalises loudness per bus. One-shots are measured over their loudest 50 ms; loops and beds over their whole length.
  - `make audio` regenerates the files. `make audio-check`, and a pytest test, fail when a committed file differs from its recipe.
- The four placeholders are replaced with generated sounds:
  - a frame saw for the sawmill;
  - an axe on timber for the lumberjack;
  - a wooden set-down for the carrier;
  - a spring wood with three kinds of birdsong for the ambient bed.
- Their manifest entries credit the generator.

## Capabilities

### New Capabilities
- (none)

### Modified Capabilities
- `audio-playback`: a new requirement, "Procedural sounds are generated in the repository".

## Impact

- **New:** `scripts/audio/` (dsp, caf, sounds, generate), `scripts/tests/test_audio_generator.py`, and the `audio` and `audio-check` Makefile targets.
- **Changed:** `Resources/Audio/loop/sawmill.caf`, `loop/lumberjack.caf`, `sfx/carrier-clink.caf`, `ambient/forest-birds.caf`, and their entries in `manifest.json`.
- **No change:** bindings and CityAudio code.
- **CI:** the sprite pipeline's pytest job runs the regeneration check on macOS, and the `changes` job runs `make audio-check` on Linux, so the "same bytes everywhere" promise is checked on both.
