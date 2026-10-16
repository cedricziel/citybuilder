## Why

Maps are archipelagos: several islands, rival towns and ships. Nothing on screen shows where the camera is on that map, where the rivals sit or where the ships sail. To get to another island, the player has to pan across open sea. The owner asked for a minimap.

## What Changes

- On iPhone, iPad and Mac, a minimap sits in a corner of the HUD. It is drawn in the same iso orientation as the map. It shows:
  - the terrain (water, beach, grass, forest, rock)
  - the player's buildings in the player colour, and each rival's buildings in that rival's colour
  - ships as dots
  - the camera's visible area as an outlined rectangle
- The terrain is drawn once into an image and redrawn only when the terrain changes, for example when trees are felled or planted. Buildings and ships are drawn on top and refreshed at most every 3 ticks. The camera frame follows the camera at once.
- A tap, click or drag on the minimap moves the camera there. A tap glides the camera, unless Reduce Motion is on: then the camera jumps.
- A HUD button shows and hides the minimap, and on the Mac so does `M`. The choice is kept across launches. It starts shown on iPad and Mac and hidden on iPhone.
- The minimap never covers the build rail, the dock, the tool strip, the banners or the inspector callout.
- Apple TV has no corner minimap. A full-screen overview opens from a Map button in the top bar, from a controller's X button, and as the fourth stop of the Play/Pause hold zoom cycle (2.0 → 1.0 → 0.5 → overview). In the overview, the remote moves a cursor, select moves the camera there, and Back closes the overview.

## Capabilities

### New Capabilities
- (none)

### Modified Capabilities
- `platform-shells`: adds requirements for the minimap, its interaction, its toggle, its layout and the Apple TV overview.

## Impact

- **CityUI:**
  - new `Minimap*` files: projection math, the terrain raster, the marker model, the view, and the preference
  - `CityRootView+Build` places the minimap
  - `InspectorCalloutView.freeArea` leaves out the minimap
  - `GameSession` gains the camera jump and the overview state
  - `RemoteInputMapper` and `GameControllerAdapter` gain the overview input
- **Apps:** no change. The toggle lives in the HUD.
- **CityCore:** no change. The minimap only reads snapshots and moves the camera, which is view state and not part of the simulation.
