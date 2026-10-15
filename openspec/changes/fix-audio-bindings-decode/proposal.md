## Why

The shipped `Resources/Audio/bindings.json` does not decode, for two reasons:
- Its `productionStalled` stop cues leave out `bus`, which the cue decoder requires.
- Its lumberjack cues name the kind `lumberjackHut`, but the raw value is `lumberjack-hut`.

`AudioBundleLoader` swallows the error and falls back to empty bindings. So in the app no bound cue plays: no placement thunk, construction chime, coins, workshop loop or music track. Nothing reports it.

## What Changes

- **Stop cues may leave out `bus`.** A stop cue plays nothing, so it has no use for one. Start cues must still name their bus.
- **The lumberjack cues use the raw value.** They now say `lumberjack-hut`.
- **Load failures are reported.** When `bindings.json` or `manifest.json` is present but fails to load, `AudioBundleLoader` reports it as a fault in the system log before falling back.
- **A test guards the shipped files.** It loads the shipped bindings against the shipped manifest.

## Capabilities

### New Capabilities
- (none)

### Modified Capabilities
- `audio-playback`: two new requirements, "Stop cues need no bus" and "A broken audio document is reported".

## Impact

- **CityAudio:** the `Bindings.Cue` decoder, and `AudioBundleLoader` with an injectable `report` that defaults to an `os` `Logger` fault.
- **Resources:** `bindings.json`.
