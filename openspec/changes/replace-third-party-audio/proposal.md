## Why

Six shipped audio files were downloaded third-party CC0 works: the one-shots `ui/click`, `ui/place-thunk`, `construction/chime`, `economy/coin`, `economy/game-over` and the track `music/bards-tale`. The project rule is that all music and sound effects are composed or synthesised in the repository. Closes #431, part of #399.

## What Changes

- Five one-shot recipes in `scripts/audio/sounds.py` replace the downloaded files at the same paths, rendered by `make audio`.
- A sixth original piece, "Lanterns on the Quay" (`music/lanterns-on-the-quay.caf`), replaces `bards-tale` in the shipped bindings, rendered by `make music`.
- `bards-tale.m4a` is deleted. The manifest credits every file to the Citybuilder generator or score. No third-party credit remains. No credits screen exists in the app, so no view or string changes.
- A pytest checks the new files' duration, peak, loudness, DC offset and end fade.

## Decisions

- `game-over` is about 2.6 s, not the 0.12 s of the file it replaces: a defeat cue that short read as a glitch.
- `ui/click` is not bound to any event. The old file was near-silent (peak about -44 dB); the new one is rendered at the `sfx` bus level like every other recipe.
- The new piece keeps the old track's place in the rotation: untagged, so it plays in every season.

## Impact

- Spec: `audio-playback` (original-music credit scenario).
- Code: `scripts/audio/sounds.py`, `scripts/audio/music/pieces.py`, `Resources/Audio`, three CityAudio tests.
