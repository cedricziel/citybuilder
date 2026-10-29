## 1. Building animations follow pause and Reduce Motion

- [x] 1.1 Tests-first: "Reduce Motion rests a building on its first frame" and "Pausing holds a building's animation"; confirm red
- [x] 1.2 Implement to green: `BuildingMotion` state switched once per change in `IsoWorldScene.update`, armed in the current state as nodes are built
- [x] 1.3 Refactor: the operational animation key carries the look's stem; `assetName` and `loopingAction` serve every building, and `operationalAction` goes
