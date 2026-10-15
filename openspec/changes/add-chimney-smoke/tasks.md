## 1. Chimney smoke

- [x] 1.1 Tests-first: translate the `rendering-2_5d` scenarios "Inhabited house smokes", "Idle workshop is cold", "Brewery steams", "Smoke budget follows zoom" and "Reduce Motion slows smoke" into failing CityRender2D tests; confirm red
- [x] 1.2 Implement `ChimneyPlanner`, `ChimneyAnchors` and `AmbientLayerNode`; wire them into `IsoWorldScene.update` and `IsoWorldView`
- [x] 1.3 Check in the Mac app (`-uiTestSeedLived`): smoke rises from the four inhabited houses; the bakery, short of flour, stays cold
