## Decisions

### D1: Positions are a pure function of town center, slot and tick

- The plaza is the front of the town center's 3×3 footprint, in footprint-local coordinates `u ∈ [0.3, 2.8]` and `v ∈ [1.5, 2.85]`, where `(0, 0)` is the back corner. The hall and tower fill the rest. The region was measured on the IsoKit render.
- A figure's day is cut into 60-tick visits. For each visit, a SplitMix64 hash of (town center id, slot, visit index) picks a spot.
- The figure walks from the previous spot to the new one during the first 20 ticks of a visit, then stands. A per-slot offset staggers the visits, so the crowd never moves in step.
- The planner reads only the snapshot and never draws from the simulation's random number generator.

### D2: Head count from nearby houses

The head count is the residents of operational houses within 12 tiles (Chebyshev distance) of the town center's anchor, divided by 3 and capped at 8. Counting nearby houses works the same for rivals' town centers, with no rival-only lookups.

### D3: Rendering

Figures reuse the walker sprites:
- A walking figure plays the walk animation for its facing.
- A standing figure shows frame 0.

Nodes are pooled by (town center, slot) and draw at z 50, as strollers do. A figure moves to each new 10 Hz position over 0.1 s, so it glides instead of jumping. Its tint comes from five muted cloth colours at a blend factor of 0.35.

### D4: Budget and Reduce Motion

The crowd is skipped below zoom 0.5 and for town centers outside the visible tile range. With Reduce Motion on, the visit index is frozen at 0, so each figure stands at its first spot.
