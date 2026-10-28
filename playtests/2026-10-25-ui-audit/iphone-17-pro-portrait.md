# UI audit: iPhone 17 Pro, portrait (2026-10-25)

A dogfood pass to prove the checklist and report format on one iPhone size. It covers part of the screen list; the rest is marked "not reached".

## Setup
- Device: iPhone 17 Pro simulator, 402 × 874 pt, iOS 27.0. Screenshots are 1206 × 2622 px (3x). Points = pixels ÷ 3.
- Build: `41d46f5f`, debug. Flags: none. Regular New Game (single island, seed 0, Normal).
- Appearance: light (dark checked in landscape). Text size: large, then accessibility XXXL.
- The host was heavily loaded; every tap showed its result 5 to 20 s late. Findings were read from stable frames only.
- VoiceOver: not read from code in this pass.

## HUD
Checked: tap targets, legibility, safe areas, overlap, Dynamic Type, contrast.
- Status pill (money, pop., island, pause, 1×): fits, nothing under the dynamic island. Pause and speed buttons look about 44 pt tall.
- **[S2] The date is missing.** Screen: HUD, new game. The status pill shows MONEY, POP., ISLAND, pause and speed, and no date, though the game has seasons and the whole map changes colour. Checklist item: legibility. `iphone-17-pro-portrait-03-large-text.png` and the newcomer screenshots show it.
- **[S1] "First steps" pill breaks at accessibility sizes.** Screen: HUD at accessibility XXXL, portrait. The pill wraps to "First / step / s 1/5" with "net $0" split letter by letter, and runs off the right edge. Checklist item: Dynamic Type. `iphone-17-pro-portrait-03-large-text.png`
- **[S2] The "..." button balloons while the status pill does not.** Same state: the menu button grows to roughly 80 pt and covers the map and the First steps pill, while the money and population text stays small. Checklist item: Dynamic Type. Same screenshot.

- **[S2] Start zoom is too close for a phone.** Screen: first game screen, default text size. The town center fills about 275 of 402 pt and no coast is visible; zoom 1.0 is the same on every device. Checklist item: reflow. `playtests/2026-10-25-newcomer/start-sequence/zoom-1.0-default.png`
- **[S1] Coachmark, "..." button and First steps pill grow past the screen at accessibility sizes.** See the newcomer report, top finding 3, for the file and line references. `playtests/2026-10-25-newcomer/start-sequence/text-size-accessibility-extra-extra-extra-large.png`

## Build rail and drawer
Checked: tap targets, truncation, reflow, contrast.
- Rail buttons (Town, Gather, Craft, Road, Demolish) are wide and tall enough; labels fit.
- **[S2] Locked tiles are hard to read.** Screen: Gather drawer and Craft drawer. The "Needs Mining", "Needs Metallurgy", "Needs Seafaring" captions are pale grey on pale tile at about 50 percent opacity. Checklist item: contrast. `iphone-17-pro-portrait-01-town-drawer.png`, `iphone-17-pro-portrait-02-craft-drawer.png`
- **[S2] Locked captions truncate mid-word.** Screen: Gather drawer, Hop Garden: "Needs Cultivatio" then "n" on the next line; Craft drawer, Brewery: "Needs Cultivatio / n". Checklist item: truncation. `iphone-17-pro-portrait-02-craft-drawer.png`
- **[S3] Two tiles in the Town and Craft drawers have no visible name.** The last tiles in the bottom row show only an icon (Gallery's label is cut to "Gallerv" in the capture; two Craft tiles have none). Checklist item: legibility. Both drawer screenshots.
- Drawer opens as a floating card above the rail; no overlap with the HUD in portrait.

## Tool strip and placement HUD
Checked: copy, tap targets, overlap.
- **[S2] The strip text does not match the iPhone flow.** Screen: Farm armed. It says "Tap or drag to place farm"; a tap opens a nudge HUD (four arrows, red cross, green check) instead. `playtests/2026-10-25-newcomer/04-farm-armed.png`
- **[S3] Unlabelled chip "6/2".** Same screen. The log icon with "6/2" has no caption on the phone.
- The nudge arrows are about 34 pt wide in the capture (104 px at 3x), below the 44 pt target. **[S2]** Screen: placement HUD. Checklist item: tap targets. Same screenshot.

## Inspector and callout
Checked: overlap, truncation.
- **[S2] The callout covers the thing you tap next.** Screen: tap the Road next to a farm. The callout sits over the farm and its status icon. `playtests/2026-10-25-newcomer/06-menu-and-road-callout.png`
- **[S2] Mid-word break "town cen-ter".** Screen: Farm callout, "Its road doesn't reach a warehouse or the town cen-ter". `playtests/2026-10-25-newcomer/08-farm-callout-problem.png`
- The "Details · Actions · Demolish" row is readable, with generous spacing.

## Panels and sheets
- Research: opens as a half sheet; list readable, "Done" at the top right is large. The blurred top-left made rows hard to read mid-transition. `playtests/2026-10-25-newcomer/07-research-sheet.png`
- Goals, standings, market, statistics, routes: not reached in this pass.

## Hints and banners
- **[S2] The coachmark covers the rail.** Screen: first screen. "Long-press a tile to build" with "Got it" sits on top of the build bar's labels. `playtests/2026-10-25-newcomer/03-coachmark-covers-rail.png`
- First steps card: readable, large type, close button about 44 pt. No problem found.

## Pause, settings, save and load
- The "..." menu lists Research, Statistics, Show Minimap, Settings; rows are tall and readable. Pause menu, settings screen, save and load: not reached.

## Landscape (same device)
- **[S2] The drawer covers the status pill.** Screen: landscape, Craft drawer open. The money, pop. and island readout is hidden behind the drawer card. `iphone-17-pro-landscape-01-craft-drawer.png`
- The rail turns into a left column without labels (icons only). **[S3]** Screen: landscape rail. `iphone-17-pro-landscape-02-hud.png`
- HUD in landscape is clean: status pill left of center, Research, Statistics, Minimap and Settings icons on the right. No overlap with the dynamic island.
- **[S1] At accessibility XXXL in landscape** the four icon buttons grow to about 100 pt and the First steps pill wraps to three lines ("First / steps / 1/5 · net $0"), covering a quarter of the map. `iphone-17-pro-landscape-04-large-text.png`
- Dark appearance: HUD and rail read well; contrast fine. `iphone-17-pro-landscape-03-dark.png`

## Not reached
Goals, standings, market, statistics, routes, hints other than the coachmark, pause menu, settings, save and load; VoiceOver labels from code; smaller and larger phones; iPad; Apple TV; Mac.
