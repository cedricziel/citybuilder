## ADDED Requirements

### Requirement: HUD reflects the camera's current island

The HUD SHALL display the name of the island under the camera and a stocks row showing the goods currently held on that island. The lookup MUST read from `WorldSnapshot.island(at: snapshot.camera.centerTile())`. When the camera is over water, the HUD MUST display the most recent island it was over (sticky behavior) so the player keeps their reference frame during sea crossings.

#### Scenario: HUD reads current island from camera

- **WHEN** the camera centers on a tile inside Island #2
- **THEN** the HUD shows Island #2's name and its `IslandSummary.stockpile` as good chips

#### Scenario: HUD is sticky over water

- **WHEN** the camera was over Island #1 and pans over open water without crossing into another island
- **THEN** the HUD continues to display Island #1's name and stocks

#### Scenario: HUD switches when camera enters another island

- **WHEN** the camera was sticky on Island #1 and pans into Island #2
- **THEN** the HUD updates to Island #2's name and stocks on the next snapshot

#### Scenario: HUD is empty when camera has never been on an island

- **WHEN** a fresh world is loaded with the camera starting over water (no `previousIsland` cached) and no Island in view
- **THEN** the HUD shows the money / population badge as usual and the island row is hidden

### Requirement: Stocks row layout

The HUD's stocks row SHALL render one chip per good with non-zero stock OR non-zero capacity on the current island. Each chip MUST display the good's icon (loaded from `Icons.atlas`) and the integer count. Goods with both zero stock AND zero capacity MUST be omitted to keep the row uncluttered.

#### Scenario: Stocks row shows goods present on the island

- **WHEN** the current island has 12 wood and 4 planks in its stockpile
- **THEN** the HUD renders two chips: a wood chip with "12" and a planks chip with "4"

#### Scenario: Goods with zero stock and zero capacity are omitted

- **WHEN** an island has warehouses storing wood and planks but no capacity at all for food
- **THEN** the food chip is not rendered

#### Scenario: Goods icon uses nearest-neighbor interpolation

- **WHEN** a good icon is rendered at any scale
- **THEN** SwiftUI's `Image.interpolation(.none)` is applied so the pixel art stays crisp
