# building-portraits-3d Specification

## Purpose
TBD - created by archiving change add-mvp-foundation. Update Purpose after archive.

## Requirements
### Requirement: 3D portrait overlay
When the player inspects a building, the inspector panel SHALL provide an opt-in "View in 3D" action that opens a SceneKit-based rotatable portrait of the building as an overlay on top of the 2D world.

#### Scenario: Inspector exposes 3D action
- **WHEN** the player taps a building to inspect
- **THEN** the inspector panel shows a "View in 3D" affordance if a USDZ asset exists for that building

#### Scenario: Portrait opens on action
- **WHEN** the player invokes the 3D portrait action
- **THEN** an overlay sheet presents a SceneKit `SceneView` rendering the building's USDZ model

### Requirement: USDZ asset per building (opt-in)
Each building catalog entry MAY declare a USDZ asset path. Buildings without a USDZ asset MUST NOT expose the 3D action.

#### Scenario: Missing asset hides 3D action
- **WHEN** a building has no USDZ asset declared
- **THEN** the inspector does not show the "View in 3D" affordance

### Requirement: Lazy loading and unloading
USDZ assets SHALL be loaded only when the portrait is opened and unloaded when the portrait is dismissed. Memory MUST not persist between portrait sessions.

#### Scenario: Memory released on dismiss
- **WHEN** the 3D portrait overlay is dismissed
- **THEN** the SceneKit scene and its loaded USDZ asset are released within one run-loop turn

### Requirement: Rotatable view
The 3D portrait SHALL allow the player to orbit and zoom the model with touch (drag to rotate, pinch to zoom) or mouse (drag to rotate, scroll to zoom).

#### Scenario: Drag rotates portrait
- **WHEN** the player drags horizontally inside the portrait
- **THEN** the camera orbits the model around the vertical axis

### Requirement: Non-blocking overlay
The portrait overlay MUST NOT pause or interfere with the underlying simulation. The simulation SHALL continue to tick while the overlay is presented.

#### Scenario: Simulation continues during portrait
- **WHEN** the 3D portrait is open for N seconds
- **THEN** the simulation has advanced 10×N ticks underneath, observable on dismiss
