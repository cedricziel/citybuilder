## ADDED Requirements

### Requirement: Trees sway in the wind

Every tree clump object SHALL rock about its anchor (the trunk base on its tile), by at most 0.7°, on a shared repeating action. Its start SHALL be offset by a phase from a hash of its tile. Rock objects SHALL NOT sway. The sway SHALL be armed when the clump's node is made, with no per-frame work per clump.

Below zoom 0.5, or with Reduce Motion on, clumps SHALL stand upright and still. While the game is paused, they SHALL hold their current lean. The scene SHALL update the clumps on screen only when this state changes, and clumps made afterwards SHALL start in the current state.

#### Scenario: A tree clump sways
- **WHEN** the scene makes the node for a forest tile with a clump at zoom 1
- **THEN** the clump runs the sway action, and its lean never exceeds 0.7°

#### Scenario: Rock stays still
- **WHEN** the scene makes the node for a mountain tile with an outcrop
- **THEN** the outcrop runs no sway

#### Scenario: Sway stops far out and with Reduce Motion
- **WHEN** the camera zooms out below 0.5, or Reduce Motion comes on
- **THEN** every clump on screen stands upright with its sway stopped, and a clump made afterwards starts stopped
