## 1. Keep the camera near the map

- [x] 1.1 Tests-first: "A view off the map draws nothing" with the camera far outside the map on all four sides; confirm it traps
- [x] 1.2 Implement to green: check the clamped bounds in `Culling.visibleTileRange` before building a range
- [x] 1.3 Tests-first, then green: "Panning far off the map stops at the margin" on all four sides; clamp the camera centre in `cameraDidMove` on every platform
