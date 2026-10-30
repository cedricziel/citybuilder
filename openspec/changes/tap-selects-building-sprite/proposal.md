## Why

In the 0.2.10 playtest, tapping a house's roof opened the Road inspector (#340). A tap selects the tile under the finger. A building's sprite rises above its footprint, so its roof stands over the tiles behind it. Only taps on the front of the lot reached the house, and the house inspector's market lines were hard to reach.

## What Changes

- With the Inspect tool, a tap on a standing building's sprite selects that building, even where the sprite covers a tile behind its footprint. A status icon still wins over the sprite. Where two sprites cover the tap, the building drawn in front wins.
- Demolish and the place tools keep tapping the tile under the finger.

## Capabilities

### New Capabilities
- (none)

### Modified Capabilities
- `rendering-2_5d`: "Input mapping" gains the sprite hit-test scenarios.

## Impact

- **CityRender2D:** `IsoWorldScene.buildingTile(at:)` and `IsoMath.isWithinBuilding`. `dispatchTap` uses them under the Inspect tool.
- **CityCore, CityUI:** no change.
