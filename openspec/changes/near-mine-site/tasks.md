## 1. Near mine site

- [x] 1.1 Measure road tiles from the home ring to the nearest mine site on `main`, both layouts, seeds 0–29
- [x] 1.2 Tests: every town center (seeds 0–29, both layouts) has a site within 10 road tiles; seed 1 raises a 3×3 outcrop 6 road tiles out; seed 9 keeps its terrain; the outcrop takes the nearest grass square outside the start area; the island-wide fallback still puts back a failed candidate
- [x] 1.3 `raiseStarterMineSite` raises a near outcrop before the island-wide fallback
- [x] 1.4 Fair start, starter mine site and rival tests still pass
- [x] 1.5 Archipelago pacing sweep before and after, and the determinism fixture hashes before and after, in the PR
