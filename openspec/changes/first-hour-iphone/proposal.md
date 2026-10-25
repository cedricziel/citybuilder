## Why

The first agent playtest (#279) and the owner found that the first hour on an iPhone is rough. A new game opens at zoom 1.0 on every device, so a phone shows about six tiles and the town center fills two thirds of the screen, with nothing to say that pinch zooms. At large Dynamic Type sizes the coachmark, the More button and the First steps pill balloon, and words break mid-word ("cen-ter", "Cultivatio / n", "First / step / s"). A red status icon gives no words until the building is tapped. The tool strip says "Tap or drag to place" when a tap opens the nudge HUD. The road callout covers the farm it leads to. The phone HUD shows no date. In landscape the Craft drawer covers the status pill. Issue #280.

## What Changes

- A new game starts at zoom 0.55 on a phone; every other device keeps 1.0. A one-time banner on touch devices says that pinch zooms.
- HUD chrome (the status pill and More button, the First steps capsule, the coachmark, the build bar and its drawer, the tool strip, the session banner, the date chip) stops growing at `accessibility1`; one-line labels shrink before they truncate, and a word never breaks. Sheets and panels keep scaling.
- A building that has shown a status icon for ten seconds is named once in a banner with its problem; tapping it shows the same line in the callout.
- On touch, the tool strip's hint for a building reads "Tap to position, then tap ✓ to place". A road keeps "Tap or drag to place road".
- The road callout moves to another side when its usual side would cover a building next to the road. On a phone the callout is wider so its problem line does not hyphenate.
- A phone shows the date in a small chip under the status pill (canvas: https://claude.ai/artifact/4ET1w6AH2i61Z7FMtVVsF7, option B). It is the first thing to go when the row is tight.
- On a short landscape screen the drawer starts under the top bar and shortens to fit.

Out of scope: a new coachmark position, the locked-tile contrast, the nudge arrows' tap size, and houses' status icons in the problem hint.

## Capabilities

### New Capabilities
- (none)

### Modified Capabilities
- `platform-shells`: modifies "iPhone compact play defaults"; adds "Pinch-to-zoom hint", "HUD chrome caps Dynamic Type", "Building-problem hint", "Touch placement hint", "Road callout keeps off neighbours", "Phone date chip" and "Landscape drawer clears the status pill".

## Impact

- **CityUI**: `StartZoom`, `NewGameDialogViewModel`, `CoachmarkStore`, `SessionBanner`, `ToolStrip`, `InspectorCallout`, `DateChipView`, `HUDChrome`, `BuildRailView`, the HUD buttons.
- **design/web**: `DateChip`, the season icons, the `GameScreen` phone date chip, the touch hint copy in the previews.
- **Determinism**: none; the camera zoom is set by the UI after the world is built.
