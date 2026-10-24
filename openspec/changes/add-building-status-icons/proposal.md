## Why

A building that isn't working only says why in the inspector, so the player has to click every building to find the stalled one. The map shows just two markers today: the construction clock and a red no-road disc. The disc is an `SKShapeNode` that pulses forever and ignores Reduce Motion. Anno answers this with a small icon that floats over the building while something is wrong. Design canvas: https://claude.ai/artifact/JMuRyVB1tHAFthEbFxdE2F (option A, "Disc", with a bob; approved).

## What Changes

- Every player building that has a `BuildingIssue`, every player house short of a need, and every road-disconnected building shows one status icon floating over its roof. The icon goes away as soon as the problem is gone.
- **Icons:** hand-written SVG in the goods-icon style.
  - A state-coloured disc (red for blocked, amber for waiting) carries a white pictogram for no road, no route to storage, no trees, no room to plant and storage full.
  - A good's issue shows the existing goods icon on a cream disc with a pip: a red "!" for a missing input or an unmet house need, an amber pause for resting or stuck output.
- **Size:** 22 pt on iPhone and iPad, 20 pt on Mac, 30 pt on Apple TV at zoom 1. The icon scales by clamp(zoom, 0.75, 1.25), so it shrinks less than the world.
- **Motion:** a 2 pt bob over 1.8 s, phase-offset per building. Under Reduce Motion the icon is static.
- **Cost:** at most one sprite node per affected building, textured from the Kit atlas. It is touched only when the issue or the zoom changes.
- **Input:** with the Inspect tool, a tap or click on the icon selects its building. Under Demolish or a place tool, the tap goes to the tile underneath. Where hit areas overlap, the nearest icon wins.
- **Removed:** the pulsing `SKShapeNode` no-road disc. The no-road status icon replaces it.
- **Design system:** `design/web` gains a `StatusIcon` component.

## Capabilities

### New Capabilities
- (none)

### Modified Capabilities
- `rendering-2_5d`: adds "Buildings show a status icon while something is wrong". "Road-access marker" now draws the no-road status icon.

## Impact

- **Art:**
  - New `scripts/art/status_icons.py` and a catalog brief `status-icons.md` (`source = "svg"`).
  - 41 new sprites in `Kit.atlas`: two per good plus five pictograms.
- **CityRender2D:**
  - New `StatusIcons.swift`, holding the issue-to-icon mapping and the reconcile.
  - Changed: `SceneNodeFactories.swift` (the shape badge is gone), `TextureFiltering.swift` (stems), `IsoWorldScene.swift` (the update call) and `IsoWorldScene+Pointer.swift` (icon taps).
- **CityCore:** no change. The mapping reads `buildingIssues`, `housePopulations` and `roadDisconnectedBuildings` from the snapshot.
- **Coordination:** #232 replaces `.storageFull` with `.outputStuck(Good)` and may drop `.resting`. Both map onto the per-good "stuck" icon, which is already drawn, so either change is one line in the mapping.
- **design/web:** the new `StatusIcon` component, republished by the design-system agent.
