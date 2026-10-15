## 1. Minimap model

- [ ] 1.1 Tests-first: "Terrain colours", "Iso orientation", "Terrain redraws only when it changes", "Buildings in their owner's colour", "Ships as dots", "Markers refresh at most every 3 ticks", "Camera frame"
- [ ] 1.2 `MinimapProjection`, `MinimapTerrainRaster`, `MinimapModel`; feed it from `GameSession.step()`

## 2. Minimap view, interaction and layout

- [ ] 2.1 Tests-first: "Tap centers the camera", "Tap glides without Reduce Motion", "Point off the map clamps", toggle and layout scenarios
- [ ] 2.2 `GameSession.centerCamera` and `CameraGlide`
- [ ] 2.3 `MinimapView` (Canvas, gesture), `MinimapPreference`, the HUD toggle with `M`, and placement in the rail and dock layouts
- [ ] 2.4 Inspector callout free area leaves out the minimap
- [ ] 2.5 Check on the Mac app: window screenshot with the minimap, click and drag move the camera, `M` toggles

## 3. Apple TV overview

- [ ] 3.1 Tests-first: the overview scenarios
- [ ] 3.2 `MapOverview` state, the mapper's routing, the controller's X, the zoom-cycle stop
- [ ] 3.3 Full-screen overview view and the Map button in the top bar
- [ ] 3.4 Check on the tvOS simulator (slot from `main`)
