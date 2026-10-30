## 1. Taps select the building under the sprite

- [x] 1.1 Tests-first: translate the `rendering-2_5d` scenarios "Tapping a building's sprite selects it", "Other tools tap the tile behind a sprite" and "The building in front takes an overlapping tap" into failing CityRender2D tests; confirm red
- [x] 1.2 Implement to green: `IsoWorldScene.buildingTile(at:)` hit-tests the standing buildings' sprites as their footprint swept up to the sprite's top, and `dispatchTap` uses it after the status icons under the Inspect tool
- [ ] 1.3 Check in the `-uiTestSeedLived` town that a tap on a house's roof opens the house inspector (orchestrator playtest)
