## MODIFIED Requirements

### Requirement: Tile context menu on long-press

CityUI on iOS SHALL present a `TileContextMenu` whenever the controller receives a `.longPressTile(coord)` intent. The menu MUST list:

1. One Build entry per kind the build palette offers, in the palette's order: every `BuildingKind` except the town center, minus buildings the player's research made obsolete (hidden, exactly as in the palette). Entries whose `canPlace(_:at:)` would reject for research, terrain, occupancy, or insufficient materials, or that the player cannot afford, MUST appear disabled and MUST say why (a locked kind reads "Needs <tech> research"). The road entry appears whenever the palette offers it.
2. A Demolish entry, visible only when the tile holds a player-owned building, rendered with the destructive role.
3. A Cancel entry that dismisses the menu and keeps the inspector selection on the long-pressed tile.

A long-press MUST also select the tile for the inspector, and the inspector SHALL offer an Actions button that opens the same menu for the selected tile.

Selecting a non-road Build entry MUST enter pending-placement mode at the long-pressed tile via `GameSession.beginPendingPlacement(kind:at:)`. Selecting the road Build entry MUST arm the road place tool via `selectedTool = .place(.road)` WITHOUT entering pending-placement mode (roads paint via drag). Selecting Demolish MUST demolish at the long-pressed tile as the demolish tool does (`platform-shells` / Demolish asks first). Selecting Cancel MUST be a no-op beyond dismissing the menu.

The menu MUST NOT present on macOS; the Mac shell continues to use the palette + click model.

#### Scenario: Menu lists every placeable building kind as a separate entry

- **WHEN** `TileMenuViewModel(tile:, world:, money:)` is built for any tile
- **THEN** its items contain exactly one `.build(kind, enabled:, reason:)` entry per kind the palette shows (including `.road`)

#### Scenario: Road menu entry arms the place tool without entering pending state

- **WHEN** the menu's road `.build(.road)` choice is applied via `GameSession.applyMenuChoice(.build(.road), at: tile)`
- **THEN** `selectedTool == .place(.road)` and `pendingPlacement == nil`

#### Scenario: Unaffordable buildings appear disabled in the menu

- **WHEN** `TileMenuViewModel` is built for a tile where the player cannot afford a sawmill (e.g. insufficient money or insufficient island materials)
- **THEN** the `.build(.sawmill, enabled: false, reason:)` entry has `enabled == false` and a reason

#### Scenario: Locked buildings appear disabled with the research reason

- **WHEN** `TileMenuViewModel` is built for a world where the mine's tech is not researched
- **THEN** the mine entry is disabled and its reason reads "Needs <tech> research"

#### Scenario: Obsolete buildings are left out of the menu

- **WHEN** `TileMenuViewModel` is built for a world that researched the tech replacing the quern house
- **THEN** the items contain no quern house entry

#### Scenario: Demolish entry appears only when tile holds a player-owned building

- **WHEN** `TileMenuViewModel` is built for a tile holding a player-owned house
- **THEN** the items contain a `.demolish` entry

- **WHEN** `TileMenuViewModel` is built for an empty grass tile
- **THEN** the items do NOT contain a `.demolish` entry

#### Scenario: Menu emits dismiss for inspect entry

- **WHEN** the menu's cancel choice is applied via `GameSession.applyMenuChoice(.dismiss, at: tile)`
- **THEN** `pendingPlacement == nil` and `selectedTool` is unchanged

#### Scenario: Long-press intent opens the tile menu request on iOS

- **WHEN** the controller receives a `.longPressTile(coord)` intent on iOS
- **THEN** `GameSession.tileMenuRequest == TileMenuRequest(tile: coord)`

#### Scenario: Menu Build choice for a non-road kind enters pending placement

- **WHEN** the menu's `.build(.house)` choice is applied via `GameSession.applyMenuChoice(.build(.house), at: TileCoordinate(x: 3, y: 4))`
- **THEN** `pendingPlacement?.kind == .house` and `pendingPlacement?.anchor == TileCoordinate(x: 3, y: 4)`

#### Scenario: Menu Build choice for road arms the road place tool

- **WHEN** the menu's `.build(.road)` choice is applied via `GameSession.applyMenuChoice(.build(.road), at: TileCoordinate(x: 3, y: 4))`
- **THEN** `selectedTool == .place(.road)` and `pendingPlacement == nil` (the player paints by tapping / dragging tiles)
