## Why

Most of the game's events make no sound:

- **Demolition and rejection:** demolishing a building, a placement the rules reject.
- **Warnings and money:** the bankruptcy warning and its resolution, market and rival trades, caravan sales.
- **Calendar and history:** a new season, history events, a new age, a rival's new age, a finished monument, a won scenario.
- **Workshops:** a commission starting, a workshop running out of fuel.

The player misses feedback, and the world feels quieter than it should. With the generator from `add-procedural-sound-generator`, we can author these sounds ourselves in a consistent, period voice: timber, bells, coins and fire.

## What Changes

- New generated one-shots, all on the `sfx` bus at one loudness:

  | Sound | Events |
  |---|---|
  | Timber collapsing | building demolished |
  | Two dull knocks | placement rejected |
  | A low warning bell | bankruptcy warning |
  | Two rising chimes | bankruptcy resolved |
  | A wind-chime flourish | season changed |
  | A handbell rung three times | history event |
  | A four-bell peal | new age (a rival's new age plays it quietly) |
  | A rising peal | scenario won |
  | A deep great bell | monument completed |
  | Embers hissing out | fuel ran out |
  | A soft two-note chime | commission started |
  | Three coin jingles, picked at random | market trade, rival trade, caravan sale |

- Each sound is bound to its events in `bindings.json`.
- The generator gains a modal bell, a coin clink and a timber-crash builder.

## Capabilities

### New Capabilities
- (none)

### Modified Capabilities
- `audio-playback`: a new requirement, "Game events have sounds".

## Impact

- **Resources:** new files in `Resources/Audio/sfx/`, their manifest entries (written by the generator), and new bindings.
- **scripts/audio:** new recipes.
- **CityAudio, CityCore:** no code change.
- **Not covered:**
  - A ship's arrival: the simulation emits no such event yet, so it needs a CityCore change first.
  - UI navigation and toggle sounds: they need a hook from CityUI and come in a later change.
