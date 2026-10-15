## 1. Chimney smoke

- [ ] 1.1 Tests-first: translate the `rendering-2_5d` scenarios "Inhabited house smokes", "Idle workshop is cold", "Brewery steams", "Smoke budget follows zoom" and "Reduce Motion slows smoke" into failing CityRender2D tests; confirm red
- [ ] 1.2 Implement `ChimneyPlanner`, `ChimneyAnchors` and `AmbientLayerNode`; wire them into `IsoWorldScene.update` and `IsoWorldView`
- [ ] 1.3 Check in the Mac app: smoke rises from inhabited houses and the bakery, none from an idle workshop, and fewer plumes when zoomed out
