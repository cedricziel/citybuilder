## Why

On Apple TV the town center market is hard to read and slow to use (#79). The inspector callout is 220 points wide on a 1920-point screen, so market rows wrap mid-word ("Coffee Cher-ries"). The market also lists every good it trades, including goods the island can never hold, such as another culture's luxuries. In a Northern European game, Wine, Tea and Coffee rows show with their Sell buttons disabled, and with the remote each row costs presses.

## What Changes

- On Apple TV the inspector callout is 520 points wide. iPhone, iPad and Mac keep 220 points.
- The market shows the goods it sells, plus the goods the island holds or produces, in catalog order. The rest of the goods it trades collapse under an "Other goods (N)" button, which expands to show them.

## Capabilities

### New Capabilities
- (none)

### Modified Capabilities
- `platform-shells`:
  - "Town center market panel" changes which rows are visible.
  - A new requirement, "Inspector callout width", sets the callout width per idiom.

## Impact

- **CityUI:**
  - `TownMarketSection` splits its rows into `rows` and `otherRows`, and `GameSession.townMarket` passes in the goods the island produces.
  - `TownMarketView` adds the Other goods button.
  - `InspectorCalloutLayout.width(for:)` returns the width per idiom.
- **CityCore:** no change. Market rules and prices are untouched.
