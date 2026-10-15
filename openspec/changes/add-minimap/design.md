## Context

- CityUI depends only on CityCore. It repeats the iso constants (64 by 32 points per tile) in `GameSession` and `PlacementHUDLayout`, so the minimap's projection lives in CityUI too.
- `GameSession.step()` builds one `WorldSnapshot` per tick and hands it to the HUD. The minimap reuses that snapshot instead of taking its own.
- `World.snapshot()` passes `terrainGrid` through, so the snapshot shares the world's array buffer. Swift's `Array ==` returns at once when two arrays share a buffer. Comparing the last drawn grid with the new one therefore costs nothing until the terrain really changes, for example when forestry turns grass into forest.
- The camera (`world.camera`) is view state saved with the game. The simulation never reads it, so moving it leaves determinism alone.

## Decisions

### D1. Minimap space is iso space in half-tile units

A tile (x, y) maps to `u = x − y` across and `v = x + y` down, the same orientation as `PlacementHUDLayout.viewPoint`. Tile centers sit at integers, and each tile covers a diamond of ±1 in `u` and `v`. The whole map's bounding box is `u ∈ [−H, W]` and `v ∈ [−1, W + H − 1]`, always 2:1. This is why every minimap size is 2:1. `MinimapProjection` maps tile ↔ minimap points and computes the camera rectangle. Like the main view, the camera rectangle is axis-aligned in this space, so it is drawn as a rectangle.

### D2. Terrain is a pixel raster, drawn off the main path

`MinimapTerrainRaster` fills an RGBA byte buffer at 2 pixels per `u` unit (an image `2(W + H)` by `W + H` pixels), capped at 512 pixels across (1,024 on Apple TV), about the largest the minimap shows. For each pixel it inverts the projection, rounds to the nearest tile and writes that terrain's colour. Pixels off the map are transparent. The buffer becomes a `CGImage` through CoreGraphics, which is available on every platform. The raster is a pure function, so tests read the bytes. `MinimapModel` keeps the raster and the last drawn grid. When the grid differs, it repaints only the pixels of the tiles that changed, and wraps the bytes in a new image at the markers' cadence, at most every 3 ticks.

### D3. Markers are rebuilt every 3 ticks

`MinimapModel.apply(_:)` runs from `GameSession.step()`. It rebuilds the building and ship marker arrays when 3 ticks have passed since the last rebuild. The arrays hold one entry per building or ship, never one per tile. The SwiftUI `Canvas` draws the cached image, the markers and the camera rectangle. The camera rectangle draws in its own layer from `MinimapModel.camera`, which the session mirrors from the world once per rendered frame, so it redraws when the camera moves and not on every tick.

### D4. Camera jump and glide

`GameSession.centerCamera(onTileX:y:animated:)` either sets the camera or starts a `CameraGlide`. The glide is a pure ease-out interpolation over 0.25 s, stepped by a main-actor task at 60 Hz. A new jump or a drag cancels a running glide. The view passes `animated: !reduceMotion` for a tap and `false` for a drag. Clamping happens in tile space, to `[0, W − 1] × [0, H − 1]`.

### D5. Layout without a new overlay layer

The minimap is laid out inside the existing HUD stacks rather than floating above them, so it cannot overlap them:

- in the rail layout, an `HStack` with the bottom stack (the rejection banner and the tool strip)
- in the dock layout, an `HStack` with the stocks tray and banner column

`InspectorCalloutView.freeArea` takes the minimap's band into account through `MinimapLayout.calloutExclusion`.

### D6. Toggle

`MinimapPreference` stores a flag in `UserDefaults` under `Citybuilder.showsMinimap`, which defaults to shown on iPad and Mac and hidden on iPhone when nothing is stored (the owner's call: the phone screen is tight). The HUD reads and writes it through `@AppStorage` with the same key. The Mac's `M` is a `keyboardShortcut` on the HUD toggle button, the way the rail keys 1, 2, 3, R and X work. It needs no command or menu entry, which keeps it apart from the Mac input change's Game menu.

### D7. Apple TV overview

`GameSession.overview` holds an optional `MapOverview`, which is the cursor's fractional tile. `RemoteInputMapper` routes input to it while it is open:

- swipes move the cursor
- a click steps the cursor 4 tiles
- select jumps the camera and closes the overview
- Back closes it
- a Play/Pause hold closes it and sets the zoom to 2.0

The Play/Pause hold cycle opens the overview from 0.5. `ControllerSnapshot` gains `buttonX`, which emits a new `RemoteInput.overview`. The TV view draws the same `MinimapCanvas` full screen, plus the cursor. All of the rules run in the macOS test run.

## Risks / Trade-offs

- **Very large maps make a large image.** A 256 by 256 map is a 1024 by 512 image, 2 MB of RGBA. That is acceptable, and the image is drawn only when the terrain changes.
- **The glide reads `CACurrentMediaTime` through a task loop.** It is view state only, so it cannot desync the simulation.
