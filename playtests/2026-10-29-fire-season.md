# Fire season (0.2.8): ship it, three layout fixes to follow (2026-10-29)

Builder playtest and UI audit of seasonal events step 1: fires, fire watch, watchman, ruins, warning banners, event chip, and the New Game "Seasonal events" toggle. Screenshots are in `2026-10-29-fire-season/`.

## Setup

- Build: `5c428824` (origin/main), Debug, iOS and tvOS simulator builds.
- Builder session: iPhone 17, landscape for the real game (the device came up in landscape and would not rotate until the app relaunched), portrait for the seeded shots. New Game: Sandbox, Single Island, Seasonal events On, seed 0 (Default), Northern European, Medieval, **Hard**. Hard has the highest event chance and the earliest first event. About 75 real minutes, 1200 to 1226 in game, mostly at 2x.
- Seeded visual checks: `-uiTestSeedFire -uiTestStartGame`, with `-uiTestSelect 36,57` (the house that burns down), `-uiTestSelect 36,63` (the fire watch), `-uiTestCamera` and `-uiTestFirstSteps`. The tiles come from running `UITestSeed.fireWorld()` headless.
- UI audit: iPhone SE (3rd generation, created for this run and then deleted), iPhone 17 Pro Max, iPad Pro 11-inch (M5) in portrait, and Apple TV 4K at 1080p. Each device was booted on its own and shut down afterwards. Mac was not covered.
- Host: load average stayed between 200 and 650 for the whole session because other agents were building. A tap often took 5 to 30 seconds to show its result, and once it took 20 minutes. Fast UI states were caught with one-second `simctl io` screenshot bursts, not with tap-and-look.

## What works

- **Toggle.** "Seasonal events" sits in the New Game dialog and defaults to On, with the copy "Dry seasons bring fires, each warned a season ahead." (`01`, `02`). I found no Quick Start option in the Sandbox dialog, so I could not check that it stays off.
- **Real game, end to end** (Hard, seed 0):
  - The chip "Fire risk · Autumn" appeared under the date in Summer 1221 (`10`).
  - In Autumn the banner "Fire! A lumberjack is burning. Without a fire watch in reach, it spreads to touching buildings and burns down to ruins." appeared (`11`).
  - In Winter the fire had spread to two touching farms, with flames and smoke on both (`12`).
  - Both farms became ruins (`13`).
  - The ruins inspector read "Ruins of a farm / Burnt down in Winter 1221 / Clear ruins — $15" (`14`), and clearing the ruins worked.
- **Fire watch** is in the Town drawer: $60 plus 2 planks, "Upkeep $1 per collection". While you place it, its teal reach diamond shows (`08`). When the watch is selected, the reach shows as thin teal lines (`27`).
- **Seeded checks** (`20`, `23`, `25`, `26`):
  - Flames and smoke draw on the burning roofs.
  - A selected burning house shows "Burning" and "Pull down — $15".
  - The inspector switches live to "Ruins of a house … Clear ruins — $15" when the house burns down.
  - "The fires are out / 1 building burnt down. Clear the ruins with Demolish." appears when the event ends.
- **Chip layout:** the chip shows its full text, without truncation or overlap, on iPhone 17 (landscape), iPhone 17 Pro Max with the First steps card, iPad portrait, and Apple TV (`33`, `35`, `40`).

## Findings, by severity

### Bugs

1. **[S2] iPhone SE: the Fire! banner is squeezed into a narrow column and covers the inspector.** With the First steps card showing, the banner is about 110 pt wide and wraps "A house is burning. Without a fire watch in reach, …" over nine lines. It covers the inspector's title, so the word "House" is hidden. The "House has a problem" banner has the same problem. Screenshot: `30-se-banner-squeezed.png`. Fires start in year 3 or later, which can still fall inside the first hour, when the card is often open. On the Pro Max the "fires are out" banner is also narrowed, but it stays readable (`34`).
2. **[S2] Two banners draw on top of each other.** When a second banner arrives, for example "House has a problem" while "Fire!" is still showing, both are drawn at once and neither can be read. Screenshot: `22-seed-banners-overlap.png`. A fire produces several banners in a few seconds, so this happens often.
3. **[S2, not fire-specific] iPhone landscape: the placement ✓ and ✗ buttons fall off the bottom edge.** When the ghost is in the lower half of the screen, the confirm buttons go off-screen, so the fire watch, or any other building, cannot be confirmed without panning first. Screenshots: `06`, `07`.
4. **[S2, not fire-specific] Apple TV: the Orders button label is drawn one letter per line** ("O r d e r s 0/2"). Screenshot: `40-tv-hud-during-fire.png`.

### UX

5. **The chip keeps saying "Fire risk · Autumn" after the fire has started**, and it still says that in Winter while the farms burn (`11`, `12`). Once a fire burns it should read as under way, not as a risk.
6. **The fire watch gives no feedback about why it did not help.** In the real game a fire watch stood next to the farms, but both still burned. The town had 0 residents, so the watch probably had no watchman, or the farms were out of its reach. The screen did not say which. The fire watch inspector shows only "State: operational / Road: connected" (`27`): nothing about reach, the watchman, or whether it is staffed. The Fire! banner always says "Without a fire watch in reach …", even when a watch is in reach.
7. **Small towns never see a fire, and the game does not say so.** A drawn fire needs at least 6 flammable operational buildings:
   - Counted: houses, producers with a recipe, warehouses, granaries, libraries, fire watches.
   - Not counted: foresters.

   For seed 0 the fire years are:
   - Easy: 1210 (summer), 1224 (autumn)
   - Normal: 1206 (autumn), 1220 (summer)
   - Hard: 1202, 1211, 1216, 1220, 1221, 1229

   My Hard town missed the fires of 1202, 1211, 1216 and 1220 because it was too small. It met the threshold just before Spring 1221, and the 1221 fire arrived on schedule. A player who switches the toggle on and has a slow start will see nothing for 10 or more in-game years. Consider a hint, or adding the condition to the toggle's copy.

8. **iPhone SE: the chip shows only the flame glyph** (`31`). This is by design, so the text never truncates. But the player cannot tell that it means fire, or which season. The chip is also about 28 pt tall, below the 44 pt minimum tap target.

### Polish

9. **The ruins inspector says "State: operational"** (`14`, `26`, `32`).
10. **The banner says to clear ruins "with Demolish", but the inspector button is "Clear ruins — $15".** Both work. The wording should match.
11. **iPad: the inspector's red action wraps** to "Pull down —" / "$15", and "Clear ruins — $15" wraps the same way (`35`, `36`).

## Not verified, and why

- **Warning banner one season ahead.** The chip appeared in the right season, but my screenshot bursts missed the warning banner itself.
- **Tapping the chip to replay the warning.** The taps landed after the seeded event had ended, about 20 seconds in. The replay is wired to the chip button (`replaySeasonalWarning`), but I did not see it on screen.
- **Watchman with his bucket.** I could not pick him out at playable zoom. The headless run of the seed confirms that the watch puts out 3 of the 4 fires (ticks 35, 113 and 185).
- **Roads as firebreaks.** Not tested.
- **Apple TV focus reaching the chip.** Arrow keys from the control tool did not move focus off the map cursor. In the code the chip is a focusable plain `Button` with the label "Fire risk · …: show the warning again". Not exercised by hand.

## Other things I noticed (not fire)

- **Hard start:** the town starts with 3 planks, but a house needs 4. You cannot build a house without trading at the market.
- **Demolish** refunds nothing and asks for no confirmation.

## Recommendation

**Ship 0.2.8.** There is no S1. The fire loop works in a real game, from warning chip through spread, ruins and clearing, and the inspector actions are right. Follow up soon on:

- item 1 (the SE banner squeeze over the inspector),
- item 2 (overlapping banners),
- item 5 (the chip wording once a fire burns),
- item 6 (fire watch feedback).
