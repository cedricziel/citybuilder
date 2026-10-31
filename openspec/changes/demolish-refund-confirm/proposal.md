## Why

Demolishing a building pays nothing back and acts on the first tap (#307). A misclick on the demolish tool, the tile menu or the inspector's Demolish loses the building and all the money spent on it, with no way back. The fire-season playtest (playtests/2026-10-29-fire-season.md) hit it.

## What Changes

- **Refund (balance):** demolishing a standing player building, finished or still under construction, pays back half its price, rounded down. A sawmill ($120) returns $60, a house ($50) $25, a road ($5) $2. Ruins and a burning building already cost a fee to clear or pull down and refund nothing. Materials are not refunded.
- **Confirmation:** demolishing a standing building other than a road asks first, naming the building and the refund: "Demolish Sawmill?" / "You get $60 back." Roads, ruins and burning buildings go at once, as before: roads are cheap and painted by dragging, and clearing ruins or pulling down a fire already shows its fee on the button.
- The same rule covers every way to demolish: the demolish tool's tap or click, the tile menu, the inspector callout and the Apple TV remote. Dragging the demolish tool demolishes only what needs no confirmation and skips standing buildings.
- On Apple TV the remote moves to the confirmation while it is open and back to the map when it closes.

## Capabilities

### New Capabilities
- (none)

### Modified Capabilities
- `economy`: adds "Demolishing refunds half the build cost".
- `platform-shells`: adds "Demolish asks first"; "Inspector callout beside the building" demolishes after the confirmation.
- `rendering-2_5d`: "Tile context menu on long-press" demolishes as the demolish tool does.

## Impact

- **CityCore**: `World.applyDemolish` credits the refund; `World.demolitionRefund(for:)`.
- **CityUI**: `GameSession.demolishRequest`, `requestDemolish(at:)`, `confirmDemolish()`, `cancelDemolish()`; a system alert on the game screen for iOS, Mac and Apple TV; the remote mapper hands focus to the alert.
- **Localization**: three new catalog keys with German.
- **Determinism**: the `DeterminismFixture` and the player bot never demolish, so their output does not change.
