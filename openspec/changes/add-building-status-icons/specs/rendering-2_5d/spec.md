## ADDED Requirements

### Requirement: Buildings show a status icon while something is wrong

The renderer SHALL float one status icon over the roof of every player building that is not doing its job, and SHALL show none over a building that is fine. The icon is chosen in this order:

1. The building's `BuildingIssue`, mapped as follows:
   - `.missingInputs(goods)` → the first good's "short" icon.
   - `.resting(good)` → that good's "stuck" icon.
   - `.storageFull` → the storage-full pictogram.
   - `.noRoad`, `.noRouteToStorage`, `.noTreesInReach` and `.noRoomToPlant` → their pictograms.
2. Otherwise, for a house, the "short" icon of the first good in its `shortGoods`, in `Good` order.
3. Otherwise, if the building is in `roadDisconnectedBuildings`, the no-road pictogram.

A "short" icon is the good on a cream disc with a red "!" pip. A "stuck" icon is the good with an amber pause pip. Pictograms are white on a red disc, or on an amber disc for storage full.

The icon SHALL be one sprite node, a child of the building's sprite, centred over the sprite's top. Its size at zoom 1 SHALL be 22 pt on iOS, 20 pt on macOS and 30 pt on tvOS. Its on-screen size SHALL follow clamp(zoom, 0.75, 1.25). It SHALL draw above the night overlay. It SHALL bob 2 pt (times its zoom scale) over 1.8 s with a phase that depends on the building's id, and SHALL be still while Reduce Motion is on.

#### Scenario: Missing input shows the good
- **WHEN** a player bakery's issue is `.missingInputs([.flour])`
- **THEN** its sprite has one status-icon child textured `status-flour-short`

#### Scenario: A house short of a need shows the good
- **WHEN** a player house has no issue and its `shortGoods` is `[.beer, .bread]`
- **THEN** its status icon is `status-bread-short`

#### Scenario: A working building shows no icon
- **WHEN** a player sawmill has no issue and has a road
- **THEN** its sprite has no status-icon child

#### Scenario: The icon goes when the issue is fixed
- **WHEN** the bakery's flour arrives and its issue clears
- **THEN** on the next reconcile its sprite has no status-icon child

#### Scenario: Reduce Motion stills the icon
- **WHEN** Reduce Motion is on and a building gets a status icon
- **THEN** the icon runs no bob action

#### Scenario: Icon keeps three quarters of its size at zoom 0.5
- **WHEN** the camera zoom is 0.5 on macOS
- **THEN** the icon's on-screen size is 15 pt

#### Scenario: Tapping the icon selects the building
- **WHEN** the Inspect tool is armed and the player taps inside a building's status icon
- **THEN** the scene dispatches `tapTile` for that building's anchor tile

#### Scenario: Other tools tap through the icon
- **WHEN** Demolish or a place tool is armed and the player taps inside a building's status icon
- **THEN** the scene dispatches `tapTile` for the tile under the tap, not the building's anchor

#### Scenario: The nearest icon takes an overlapping tap
- **WHEN** the hit areas of two status icons both cover the tap
- **THEN** the tap selects the building whose icon centre is nearer

## MODIFIED Requirements

### Requirement: Road-access marker

The world snapshot SHALL list every building, other than roads, that has no road tile orthogonally adjacent to its footprint. The renderer MUST show the no-road status icon ("Buildings show a status icon while something is wrong") above each listed building, and MUST remove it as soon as a road touches the building. The building inspector MUST show a "Road:" line that reads "connected" or "none".

#### Scenario: Snapshot lists a building without an adjacent road

- **WHEN** a house stands with no road tile next to any of its footprint tiles
- **THEN** the snapshot's set of road-disconnected buildings contains the house

#### Scenario: A touching road clears the snapshot entry

- **WHEN** a road is placed on a tile orthogonally adjacent to that house's footprint and one tick runs
- **THEN** the snapshot's set of road-disconnected buildings no longer contains the house

#### Scenario: Disconnected building sprite carries the no-road marker

- **WHEN** the renderer reconciles a snapshot listing a building as road-disconnected
- **THEN** the building's sprite has a status-icon child textured `status-no-road`

#### Scenario: Inspector reports road access

- **WHEN** the inspector is opened on a building listed as road-disconnected
- **THEN** its lines include "Road: none"
