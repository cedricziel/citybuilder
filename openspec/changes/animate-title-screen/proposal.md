## Why

The title screen is a column of grey buttons on a blank background. It is the first thing a player sees, and it says nothing about the game: no island, no light, no movement. The owner wants a warm, period city-builder feel from the first frame.

## What Changes

- The title screen draws the starting island behind its menu, through the same SpriteKit renderer the game uses. The camera drifts slowly around the town, and the light runs as a time-lapse: a slow day from morning to evening, then a quick night.
- The title and the menu buttons enter one after another with a short fade and rise.
- On iPhone, iPad and Mac the menu buttons shrink slightly when pressed and lift when the pointer hovers. Apple TV keeps the system button styles and their native focus lift.
- With Reduce Motion on, the island stands still in morning light, the menu appears at once, and presses change brightness without scaling.

## Capabilities

### New Capabilities
- (none)

### Modified Capabilities
- `platform-shells`: three new requirements, "Title screen shows the island", "Title menu entrance" and "Title menu buttons respond to touch and pointer".

## Impact

- **CityUI:**
  - New `TitleBackdrop`, which builds the island off the main thread and feeds the registered renderer a snapshot whose camera and clock follow `TitleBackdropMotion`.
  - `TitleScreenView` layers the backdrop, a scrim, and the menu with `MenuEntrance` timing and `TitleMenuButtonStyle`.
  - `SnapshotRendererRegistry.factory` is nil until an app registers a renderer, so tests and previews show a plain gradient.
- **CityCore:** `WorldSnapshot.camera` and `tickCount` become settable, so a renderer can show a still world through another camera at another time of day.
- **CityRender2D:** no change.
- **Performance:** the island is generated once, on a background task. Each frame copies one snapshot struct, which the renderer already reconciles every frame in the game.
