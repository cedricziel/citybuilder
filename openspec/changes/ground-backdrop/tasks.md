## 1. Plain ground as one backdrop

- [x] 1.1 Measure what is left at zoom 0.25 after #202, and compare chunk baking, coarser sprites and a ground backdrop (#205)
- [x] 1.2 Tests first: "Plain ground is one node", "Transition tiles keep their sprites", "Plain ground follows the terrain", "Trees and rocks keep their place over the backdrop", "Each tile animates on its own phase", "The ground backdrop follows the season"
- [x] 1.3 `GroundBackdropMap`, the look strip and the shader; plain tiles get no ground sprite, and objects over them stand alone
- [x] 1.4 Before and after on the Mac app and the simulators: nodes, draws and fps at zoom 0.25 and 1 and in the lived town; every overlay and every season, by day and at night, looks the same
