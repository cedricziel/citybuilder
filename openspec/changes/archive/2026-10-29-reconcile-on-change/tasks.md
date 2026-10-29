## 1. Reconcile only on change

- [x] 1.1 Tests-first: "An unchanged frame reconciles nothing", "A pan redraws only the edges", "A new building redraws only the tiles round it" and "Incremental frames match a full rebuild"; confirm red
- [x] 1.2 Implement to green: `VisibleTiles`, settled on the same on-screen test the full scan used
- [x] 1.3 Implement to green: the terrain and building passes in `IsoWorldScene+Sprites.swift`, with season and look changes dropping only what they redraw
- [x] 1.4 Measure idle, pan and live frames at zoom 0.25 and 1 on the archipelago, before and after (#175)
