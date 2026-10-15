## Why

The game has one ambient bed, spring birdsong, and it plays all year and everywhere. Winter sounds like May, and the shore sounds like the middle of a forest. The owner wants the world to sound like where you are and when: winter wind, summer insects, surf near the water. Beds should crossfade, never cut.

## What Changes

- **Four seasonal land beds**, generated:
  - spring: the existing birdsong;
  - summer: crickets and cicadas over a warm breeze, with few birds;
  - autumn: gusting wind through dry leaves and a distant crow;
  - winter: a cold wind whistling, and nothing else.
- **A coastal bed**, generated: waves swelling and breaking on a beach, and gulls.
- **The mix follows the context.** `AmbientScene` reads the season from each snapshot. It also reads how much of the land around the listener (the camera's centre tile, radius 6) is sea. It then sets a gain for each bed:
  - the season's bed at full, softened by up to half near the sea;
  - the coastal bed at the sea share, scaled up.
- **Gains glide.** They move toward their targets by wall-clock time, 0.25 per second, so a full crossfade takes 4 s at any game speed and while paused; `AudioStack` drives this from its own 10 Hz timer. A bed starts silent and stops once it has faded out.
- **Session end stops the beds.** When the player leaves a game, every bed stops and the scene forgets the game, so the title screen is quiet.
- **No click at the loop wrap.** The IMA4 encoder starts its first packet on the first sample's top 9 bits, with the step size the signal settles to, instead of from silence; every sound is regenerated.
- **Bindings.** The `ambient` section gains `seasons` (a file per season) and `coast`. A section without them keeps the single-track behaviour.

## Capabilities

### New Capabilities
- (none)

### Modified Capabilities
- `audio-playback`: a new requirement, "Ambient beds follow season and shore".

## Impact

- **CityAudio:**
  - `Bindings.AmbientSection` gains `seasons` and `coast`.
  - New `AmbientScene`, holding the pure mix and the glide.
  - `EngineCuePlayer.setLoopVolume(path:volume:)`.
  - `AudioStack` feeds the scene snapshots, ticks and listener moves.
- **Resources:** four new ambient beds, their manifest entries, and the ambient bindings.
- **scripts/audio:** five recipes (spring is the existing one).
