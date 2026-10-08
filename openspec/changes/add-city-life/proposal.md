## Why

The core fun is supply chains *and* a pretty, lively city. The city is pretty now, but it is still: carriers move goods, and nothing else moves, the light never changes, and a house is a number in the inspector. The game direction asks for walkers on the streets, day and night, and residents the player can meet.

## What Changes

- **Day and night:** a day lasts 1,200 ticks (two minutes). The scene darkens through dusk into a blue night and brightens at dawn; at night, inhabited houses show warm lit windows.
- **Street life:** inhabited houses send residents out to stroll the roads next to them during the day — more residents, more strollers, up to three per house. They are drawn from the snapshot, not simulated, so they cost nothing in saves or determinism.
- **Residents:** each house has named residents (from a name list per culture, chosen deterministically from the house's ID). The inspector lists up to three of them with their tier and a wish: the first unmet need ("wants bread"), or "content" when every need is met.
- **HUD clock:** the date label gains a sun or moon glyph for the time of day.

Ambient sound that follows day and night waits for audio assets and is left for a later change.

## Capabilities

### New Capabilities

- `city-life`: time of day, resident names and wishes.

### Modified Capabilities

- `rendering-2_5d`: night shading, lit windows and strollers.
- `platform-shells`: inspector residents and the HUD day/night glyph.

## Impact

- **CityCore:** `TimeOfDay` derived from the tick count, `World.residentNames(for:)` and `HousePopulation.wish(in:)`; no new stored state.
- **CityRender2D:** a night overlay node, window-glow children on houses, a stroller layer.
- **CityUI:** inspector lines, HUD glyph.
