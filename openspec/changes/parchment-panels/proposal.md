## Why

The build drawer, the inspector callout and the Statistics sheet use the stock system look: grey glass and monospaced sentences such as "Needs: food ✓ · planks ✗". They read like a settings screen rather than part of the game, and the player has to read whole lines to spot what is wrong. The owner chose the parchment option on the design canvas (https://claude.ai/artifact/WGLYmM7zotNzD1ZbTG9JTu).

## What Changes

- A shared parchment surface (cream paper, brown edge, dark ink, serif headings) for the panels that describe the town. The history and age banners already use it and now share it.
- The inspector callout is drawn on parchment, pointer included. Its header shows the building's picture, its name in serif and a house's tier as a tag. A problem shows as a dark red alert. A house's needs show as good icons, the missing ones highlighted. A producer shows what it takes in and makes as good icons with an arrow.
- Build drawer tiles are drawn on parchment, with the good the building makes as a badge in the corner.
- The Statistics sheet uses the parchment background for its list and charts.
- The build rail, status pill and other always-visible controls stay on glass so the map shows through.

## Capabilities

### New Capabilities
- (none)

### Modified Capabilities
- `platform-shells`: new requirements "Parchment panels", "Callout shows goods as icons" and "Drawer tiles show what they make".

## Impact

- **CityUI:** new `Parchment` style; `InspectorCalloutView`, `BuildDrawerView`, `StatisticsSheetView` and `SessionBannerView` use it. `InspectorViewModel` gains `needChips` and `recipe`.
- **design/web:** `Parchment` foundation; `Inspector`, `BuildDrawer` and `StatisticsPanel` follow the game.
- **CityCore, CityRender2D:** no change.
