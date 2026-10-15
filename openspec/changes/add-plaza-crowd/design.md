## Decisions

### D1: Positions are a pure function of town center, slot and tick

- Each town center look has a `PlazaLayout`, measured on its sprite. It lists lanes of open spots plus the props to keep clear of:
  - The Northern European IsoKit look has three lanes: between the hall and the stalls, along the front edge, and right of the yellow stall. Its props are the hall and tower, the well, both stalls, the barrels and the crate.
  - The culture looks fill their footprint with the building, so their lanes run along the paved rim of the two front edges.
- A test checks every spot, and every straight walk inside a lane, against the props.
- Each slot belongs to one lane (slot mod lane count) and has a rank in it (slot div lane count).
- A lane's day is cut into 60-tick visits. For each visit, a `DeterministicRNG` hash of (town center, lane, visit) picks the lane's rotation, and each rank takes the spot that many places on. So figures in one lane never share a spot.
- A figure walks from the previous spot to the new one in 20 ticks. Each rank sets off 6 ticks after the one before it, and lanes are staggered against each other.
- The planner reads only the snapshot.

### D2: Head count from nearby houses

The head count is the residents of operational houses within 12 tiles (Chebyshev distance) of the town center's anchor, divided by 3 and capped at 8. Counting nearby houses works the same for rivals' town centers, with no rival-only lookups.

### D3: Rendering

Figures reuse the walker sprites:
- A walking figure plays the walk animation for its facing.
- A standing figure shows frame 0.

Nodes are kept by (town center, slot). A figure draws just above its town center (`depthZ(depth) + 0.004`), so a building nearer the camera covers it. Strollers now sort the same way, by their road tile. A figure glides to each new 10 Hz position over 0.1 s. When no new tick has arrived for 0.3 s (the game is paused), walking figures drop to their standing frame. Its tint comes from five muted cloth colours at a blend factor of 0.35.

### D4: Budget and Reduce Motion

The crowd is skipped below zoom 0.5 and for town centers outside the visible tile range. With Reduce Motion on, the visit index is frozen at 0, so each figure stands at its first spot.
