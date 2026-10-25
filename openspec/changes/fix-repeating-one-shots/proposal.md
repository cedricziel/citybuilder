## Why

On iOS a single sound sometimes stutters ("drrrrrr") about a hundred times in a row while the game hangs (#264).

A frame can dispatch many copies of one one-shot. At triple speed one timer firing runs three ticks, and a headless run of a rival archipelago game found more than four identical sound-effect cues in 30 % of firings: up to 17 carrier arrivals, and 35 placements plus 34 completions when the rivals lay out their towns. Each bus has four one-shot nodes. Every cue past the fourth takes a busy node, and the node queue stops it, schedules the file again and starts it. `AVAudioPlayerNode.play()` waits for the engine's next I/O cycle, so the queue restarts one node per I/O cycle: the first few milliseconds of the same sample, retriggered every 11 ms on a Mac and every 23 ms or more on iOS. A burst of 100 cues kept the queue busy for 1.1 s on the Mac. While it runs, main-thread graph calls (attaching a loop's node, setting a bus volume) take about one I/O cycle each instead of under 2 ms. The worst second of the modelled run needed 113 restarts, which a 23 ms I/O cycle cannot keep up with, so on iOS the queue falls further behind.

## What Changes

- **Identical one-shots are rate-limited.** A cue is a file for one binding key (event or interface sound). A one-shot doesn't start when the same cue started under 50 ms ago, or has already started 6 times in the last second. The cue is dropped, not deferred. A burst in one frame plays once.
- **A busy node is not restarted.** One-shots are cached as whole buffers, converted on load to one pool format (44.1 kHz stereo); the shipped one-shots mix mono 44.1 kHz with stereo 48 kHz, and a node connected for one format traps on a buffer of another. A pool node that already runs takes the next one-shot with `scheduleBuffer(_:at:options:)`, interrupting its current cue when that hasn't ended, so it never waits for an I/O cycle. Only a node's first start in an engine run calls `play()`.
- **Repeats never queue up.** A one-shot is dropped while the same cue still waits on the node queue, which loop and music starts can hold up for an I/O cycle each. Different cues are never dropped for waiting.
- **A restart drops cues queued before it.** A one-shot queued before the engine stopped or restarted is dropped instead of played in the new run.
- **Voice start and stop are idempotent.** Starting a voice twice, or stopping it twice, does nothing the second time, and a stopped voice never starts again.

## Capabilities

### New Capabilities
- (none)

### Modified Capabilities
- `audio-playback`: new requirements "Identical one-shots are rate-limited", "One-shot starts never back up", "One-shots play in one format" and "Voice start and stop are idempotent".

## Impact

- **CityAudio:** a pure `OneShotLimiter`; `EngineCuePlayer` caches one-shots as PCM buffers; `OneShotBuffer` converts one-shots to the pool format; `DispatchedCue` carries its binding key; `OneShotDriver` interrupts a running node instead of restarting it, tracks which cues wait on the queue and drops stale ones; `AudioNodeQueue` knows the engine's current run; `PlayerVoice` tracks its phase instead of a generation counter.
- **Memory:** the one-shots in the shipped bindings total about 37 s of mostly mono audio, under 13 MB as stereo float buffers if every one plays.
- **Bindings, the coordinator and ducking are unchanged.** The coordinator still dispatches one cue per event; the cue player decides whether it sounds.
