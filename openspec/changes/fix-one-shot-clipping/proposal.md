## Why

The review of `add-event-sounds` found two problems.

- **One-shots cut each other off.** One-shots on a bus share four player nodes in strict round robin, and each play hard-stops whichever node comes next, even one still playing. So four quick sounds after a new age's multi-second peal cut the peal off mid-ring, with a click.
- **A misspelled key fails silently.** A binding whose key is not a real `WorldEvent` case name never fires, and nothing reports it.

## What Changes

- **A one-shot goes to a free node.** It takes the next node in the rotation that is not still playing. When every node is busy, it takes the one that finishes soonest, but never one playing a long cue (over 1.5 s) while a short one could go instead.
- **A test checks every bound key.** Every key in the shipped bindings must be a `WorldEvent` case name the coordinator produces, or an interface sound name (`ui.*`).

## Capabilities

### New Capabilities
- (none)

### Modified Capabilities
- `audio-playback`: two new requirements, "One-shots don't cut off long sounds" and "Every bound key is a real event".

## Impact

- **CityAudio:** a pure `OneShotPool.pick`, and `EngineCuePlayer` tracking when each one-shot node frees up.
- **Tests only:** a check of the shipped bindings' keys.
