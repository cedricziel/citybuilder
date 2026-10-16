## Why

The town center's plaza, with its well and market stalls, sits empty even in a busy town. Residents milling about the plaza make a town read as inhabited from the moment the camera lands on it.

## What Changes

- By day and at dusk, each operational town center shows up to 8 residents on its plaza: one for every 3 residents of the houses within 12 tiles. Each wanders between spots on the plaza and stands for a while at each one.
- Each figure gets a muted clothing tint, chosen from its town center and slot, so the crowd is not a row of clones.
- With Reduce Motion on, the figures stand at their spots and do not wander.
- Below zoom 0.5 the crowd is not drawn, because the figures would be too small to read.
- The figures are drawn from the snapshot alone and never touch simulation state. Their walker sprites are the existing ones, which the art agent will redraw later.

## Capabilities

### New Capabilities
- (none)

### Modified Capabilities
- `rendering-2_5d`: adds the requirement "Residents gather on the plaza".

## Impact

- **CityRender2D:**
  - `PlazaCrowdPlanner` works out positions as a pure function of the town center, slot and tick.
  - `IsoWorldScene` reconciles pooled figure nodes.
- **CityCore:** no change.
